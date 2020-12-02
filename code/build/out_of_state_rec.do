* Create an adjusuted REC price accounting for other states REC prices
clear
local fname out_of_state_rec

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
/* BRING IN EXCEL SPREADSHEET WHERE I CALCULATED: 

	These Excel sheets contain a variable called share_r_s:
			the share of RECs generated in state r that were 
			redeemed in state s
*/
forval y = 2012 / 2013 {
	import excel "$dropbox\Data\public\recs_tracking\REC-Tracking-data-viewer.xlsx", sheet("REC Share Variable_`y'") firstrow clear
	drop if states == ""
	gen year = `y'
	tempfile s_`y'
	save "`s_`y''"
}
use "`s_2012'"
append using "`s_2013'"

/* Only have share variables for 2012 and 2013
	APPLY IN FOLLOWING WAY:
	Apply 2012 share variables to 2012 and all years before
	Apply 2013 share variables to 2013 and after
*/
capture program drop assign_year_categories
program define assign_year_categories
	gen before_or_2012 = cond(year <= 2012, 1, 0)
end

assign_year_categories
drop year

bys state: gen num_obs = _N
assert num_obs == 2
egen num_cats = nvals(before_or_2012), by(state)
assert num_cats == 2 //should have 2012 and 2013 value

rename states state
tempfile out_of_state_recs
save "`out_of_state_recs'"

* BRING IN MONTHLY REC PRICES FOR STATES WITH REC PRICES
use "$generated_data/state_year_month_rps_rec.dta", replace
keep if state != "DC"
keep state year month rec_price

assign_year_categories

* THIS IS GOING TO MATCH 2012 TO ALL YEARS BEFORE 2012 WITHIN EACH STATE
* AND MATCH 2013 SHARE TO ALL YEARS AFTER OR ON 2013 WITHIN EACH 
* ONLY KEEPS THE MATCHES
joinby state before_or_2012 using "`out_of_state_recs'"
drop before_or_2012

/* GOAL:

   CREATE A WEIGHTED REC PRICE AVERAGE BY SUMMING REC_PRICE_IN_S * SHARE_R_S
   
   BUT WE DON'T HAVE REC PRICES FOR ALL STATES.
   
   GOING TO RE-WEIGHT PROPORTIONS SO THAT IF WE HAVE 4 STATES WITH 1/4 AND ONE
   IS MISSING REMAINING 3 GET 1/3
 */
gen missing_rec = cond(rec_price == ., 1, 0)

foreach var of varlist share* {	
	local state_r = substr("`var'", 7, 2)
	* GENERATE A TOTAL AMONG THOSE THAT NON-MISSING
	bys year month: egen sum_`state_r'_nomissing = total(`var' * !missing_rec)
	
	* CALCULATE NEW SHARE BY DIVIDING BY TOTAL AMONG NON-MISSING
	bys year month: gen new_share_`state_r' = `var' / sum_`state_r'_nomissing if !missing_rec
}

* NO LONGER NEED OLD SHARES
keep year month missing_rec rec_price new_share*

* MAKE SURE THEY RE-WEIGHTED PROPORTIONS SUM TO 1 or 0
preserve
	collapse (sum) new_share*, by(year month)
	foreach var of varlist new_share* {
		qui summ `var'
		local round_max = round(`r(max)', 1)
		assert `round_max' == 0 | `round_max' == 1
	}
restore

/* NOW CALCULATE REC FOR SEACH STATE BY:
        SUMMING SHARE OF STATE_R_S * PRICE IN STATE *
*/
foreach var of varlist new_share* {
	local state_r = substr("`var'",11, 2)
	
	* ONLY FILLED IN FOR OBS WITH REC PRICES
	gen expected_`state_r'_rec = `var' * rec_price
}
* KEEP ONLY EXPECTED_REC FOR SEACH COLUMN AND SUM TO GET WEIGHTED AVG
collapse (sum) expected_*, by(year month)

/* TRANSPOSE THE MATRIX

YEAR    MONTH          CA_EXPECTED_REC        MD_EXPECTED_REC       
2012     1                  x                      y

TO

STATE  YEAR   MONTH  EXPECTED_REC
CA      2012     1      x
MD      2012     1      Y
*/
local state_list
foreach var of varlist expected* {
	local state_list `state_list' `=substr("`var'", 10, 2)'
}
* LOOP THROUGH COLUMNS KEEP ONLY THAT STATE'S COLUMN. APPEND ALL WITH STATE VARIABLE
foreach state in `state_list' {
	preserve
		qui {
			keep year month expected_`state'_rec
			gen state = "`state'"
			rename expected_`state'_rec expected_rec
			tempfile rec_`state'
			save "`rec_`state''"
		}
	restore
}
clear
* APPEND ALL OF THE D-SETS
foreach state in `state_list' {
	append using "`rec_`state''"
}
label var expected_rec "Average REC Price adjusted for out-of-state"
order state year month
sort state year month
compress
save "$generated_data/recs_out_of_state_adjustment.dta", replace
********************************************************************************
tempsetup
capture log close
exit
