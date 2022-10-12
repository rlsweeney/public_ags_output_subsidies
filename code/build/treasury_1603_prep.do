/* Pull in and clean Treasury 1603 grant info */
local fname treasury_1603_prep
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
import excel using "$dropbox/Data/proprietary/treasury/treasury_eia_match.xlsx", clear first case(lower)
rename (facilityid_eia sample) (facilityid flag_sample_1603)
keep facilityid tan award_date amount_funded  flag_sample_1603
destring facilityid, replace
drop if facilityid == .
drop if facilityid == 56608 & tan == 20256 //could not match to our sample

* Projects with multiple awards (diff. phases). Sum amount by facilityID 
duplicates tag facilityid, gen(dup)
preserve 
	 keep if dup > 0
	 collapse (sum) amount_funded (count) n_1603_grants = amount_funded (firstnm) flag_sample_1603 , by(facilityid)
     tempfile multiple_grants
	 save "`multiple_grants'"
restore

drop if dup > 0
append using "`multiple_grants'"

replace n_1603_grants = 1 if n_1603_grants == . //for facilities w/o dups
*Generate flag for the 6 plants that have funding across multiple years
gen multiple_years = cond(inlist(facilityid, 56961, 57131, 57159, 57189, 57303, 57867), 1, 0)
gen multiple_grants = cond(tan == ., 1, 0)

gen a1603 = 1

replace award_date = "17-Dec-12" if award_date == "December 17, 2012"
gen date = date(award_date, "DMY", 2020)
drop award_date dup tan
ren date award_date
format award_date %td

la var n_1603_grants   "Number of obs in Treasury data"
la var multiple_grants "Multiple 1603 Grants Indicator for Various Phases - (amount funded summed)"
la var multiple_years  "Multiple 1603 Grants Across Years"
la var amount_funded   "1603 Award Amount in USD"
la var award_date 	   "1603 Award Date"
la var a1603 		   "Indicator for receiving 1603 Grant"

sort facilityid
order facilityid award_date
compress
save "$generated_data/1603_info.dta", replace
********************************************************************************
tempsetup
capture log close
exit
