* Prepare Instate REC and RPS Information
clear
local fname rec_prep

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
********************************************************************************

**************************
* BRING IN AND CLEAN RECS
**************************
import excel using "$dropbox/Data/proprietary/recs_prices/Market Data Price Report.xlsx", clear first case(lower)
qui {

	dropmiss, force
	*** GENERATE STATENAMES
	gen state = "Massachusetts" if regexm(instrumentname, "Massachusetts")
	foreach v in Alabama Arizona Arkansas California Colorado Connecticut Delaware DC Florida Georgia ///
				 Hawaii Idaho Illinois Indiana Iowa Kansas Kentucky Louisiana Maine Maryland Michigan /// 
				 Minnesota Mississippi Missouri Montana Nebraska Nevada  Ohio Oklahoma Oregon ///
				 Pennsylvania Tennessee Texas Utah Vermont Virginia Washington Wisconsin Wyoming {	
		replace state = "`v'" if regexm(instrumentname, "`v'")
	}

	foreach v in Hampshire Jersey Mexico York {
		replace state = "New `v'" if regexm(instrumentname, "`v'")
	}

	foreach v in "North Carolina" "North Dakota" "Rhode Island" "South Carolina" "West Virginia" {
		replace state = "`v'" if regexm(instrumentname, "`v'")
	}

	***Find REC Class
	gen recclass = "Class I" if regexm(instrumentname, "Class1")
	foreach v in "Class I" "Class II" "Class III" "Class IV" "Tier I" "Tier II" "Tier III" "Tier IV" {
		replace recclass = "`v'" if regexm(instrumentname, "`v'")
	}

	***In-State Indicator Variable
	gen instate = regexm(instrumentname, "In-State")
	***Adjacent-State Indicator Variable
	gen adjstate = regexm(instrumentname, "Adjacent-State")
	***Solar Indicator Variable
	gen solar = regexm(instrumentname, "Solar")
	replace solar = 1 if regexm(instrumentname, "SREC")
	replace solar = 0 if regexm(instrumentname, "Non-Solar")

	***Seasonal vs. Annual
	gen period = "Annual" if regexm(instrumentname, "Annual")
	replace period = "Seasonal" if regexm(instrumentname, "Seasonal")

	***Program
	gen program = "RPS" if regexm(instrumentname, "RPS")
	foreach v in NOx Nox SOx Sox SO2 "Carbon Allowance" {
		replace program = "`v'" if regexm(instrumentname, "`v'")
	}
	replace program = "SOx" if regexm(instrumentname, "Sox")
	replace program = "NOx" if regexm(instrumentname, "Nox")

	replace instrumentname = "Massachusetts Class I REC" if instrumentname == "Massachusetts Class One REC"
	
	replace state = "District of Columbia" if state == "DC"
}


* Command that brings in state abbreviations and fips codes given state fullnames
statastates, name(state)
replace state= proper(state)
drop if _merge == 2
drop _merge
rename state_fips stfips

/*  Create Indicator for whether a REC is applicable to wind farm projects
coming online - state by state */
gen wind_rec = 0
label var wind_rec "REC price is applicable to new wind farms"

*CA
replace wind_rec = 1 if instrumentname == "California Wind REC" & state_abbrev == "CA"

*CT - Class I appplies to wind
replace wind_rec = 1 if recclass == "Class I" & state_abbrev == "CT"

*DE - FLAG DSIRE page indicates DE applies to all wind
replace wind_rec = 1 if inlist(instrumentname, "Delaware Existing REC", "Delaware New REC")

*DC - TIER I applies to wind
replace wind_rec = 1 if state_abbrev == "DC" & recclass == "Tier I"

replace wind_rec = 1 if state_abbrev == "IL" & ///
inlist(instrumentname, "Illinois MRETS Registered Wind","Illinois PJM-GATS Wind", "Illinois Wind")

replace wind_rec = 1 if state_abbrev == "ME" & instrumentname == "Maine New REC" 

*MD - TIER I applies to wind
replace wind_rec = 1 if state_abbrev == "MD" & recclass == "Tier I"

* MA - Class I includes Wind. Class II only applies to wind operating before Jan 1, 1998
replace wind_rec = 1 if state_abbrev == "MA" & recclass == "Class I"

*MI - only one instrumenttype in Michigan and it applies to wind
replace wind_rec = 1 if state_abbrev == "MI"

*NH - Class I includes wind energy that began operation after Jan 1, 2006
replace wind_rec = 1 if state_abbrev == "NH" & recclass == "Class I"
 
*NJ- wind applies to class I. FLAG: SAYS CLASS II applies to
*"offshore wind" - wind located in ATlantic Ocane and connected to NJ electric transmission system
replace wind_rec = 1 if state_abbrev == "NJ" & recclass == "Class I"

*OH - seems like all non-solar apply to wind except I cannot find anything for Ohio Compliance Non-Solar
replace wind_rec = 1 if state_abbrev == "OH" & ///
inlist(instrumentname, "Ohio Adjacent-State Non-Solar", "Ohio In-State Non-Solar")

*PA - wind only in Tier I
replace wind_rec = 1 if state_abbrev == "PA" & recclass == "Tier I"

*RI - Has "New" and "Existing" Rec. Looks like Wind applies to all
replace wind_rec = 1 if state_abbrev == "RI"

*TX - qualifying systems are those installed after 9/1999
replace wind_rec = 1 if state_abbrev == "TX"

gen year = year(date)
gen month = month(date)

* Prepare to merge with RPS data
drop if state == ""
keep instrumentname state_abbrev wind_rec year bid offer date month
order state year date instrumentname

*Take average of bid and offer
gen rec_price = (bid + offer) / 2
drop bid offer


/* We want one price per state-month. 
   If a state-month has RECS that apply to wind. Take average
   of only those. 
   Otherwise if there is no wind recs just take average of any REC
*/
rename state_abbrev state

*Number of wind_recs in that STATE_year_month
bys state year month: egen wind_rec_count = total(wind_rec == 1)

*Make sure you don't lose any state-year-months
qui unique state year month
local before =`r(unique)'

* If there is a wind_REC in a state-year-month, can drop non_wind rec. Those don't matter
drop if wind_rec != 1 & wind_rec_count > 0
qui unique state year month
assert `r(unique)' == `before' //make sure you do not lose any state-month-year

/* Now take an average of what's remaining
   If a state month year has a wind rec month will only be taking averages of wind RECs
   If there are no wind, it's just an average of all RECs
*/
collapse (mean) rec_price, by(state year month)

sort state year month

tempfile rec_state_year_month
save "`rec_state_year_month'"

**************************************************************
* BRING IN EIA RETAIL SALES OF ELECTRICITY - ONLY KEEP TOTAL
**************************************************************
import excel "$dropbox\Data\public\eia\eia_861\sales_annual.xlsx", cellrange(A2:I3082) firstrow clear
renvars, lower
keep year state industrysectorcategory total
keep if industry == "Total Electric Industry"
drop industry
sort state year
rename total total_retail_sales
order state year total
drop if state == "US"
tempfile eia_annual_sales
keep if year >= 1999
save "`eia_annual_sales'"


*********************
* PROCESS RPS
*********************
import excel "$dropbox\Data\public\LBL\RPS_Compliance_Data.xlsx", cellrange(A35:AK152) firstrow clear
renvars, lower
drop notes datasources
drop rpsachievement-ak

/* Renaming RPS obligations variables to obli_1999, oblig_2000, etc)
   Use MACRO to create the list of newnames  */
local new_names
forval year = 1999/2014 {
	local new_names `new_names' oblig`year'
}
rename (rpsobligations-t) (`new_names')
drop if totalrpsortier == "" //drop first row

* Replace "-" with "0" to enable destring
foreach var in `new_names' {
	replace `var' = "0" if `var' == "-"
}
replace oblig2014 = "0" if oblig2014 == "no data"
destring `new_names', replace

rename (rpsstates totalrpsortier) (state tier)

*States take up multiple rows in the excel sheet
carryforward state, replace

*Bring Obligations into Long Format
reshape long oblig, i(state tier) j(year)
replace tier = trim(tier)

/* Foreach state-year, summ all applicable carVe-outs that we don't want to include in our
   obligation. This code will summ only those that fit the regexms below
*/
bys state year: egen carve = total(oblig * ((regexm(tier, "DG Carve-Out") | regexm(tier, "Solar") | ////
                                   regexm(tier, "Poultry Waste") | regexm(tier, "Swine Waste")) & !regexm(tier, "Non-Solar")))

* NOW RPS_OBLIGATION = TOTAL OBLIGATIONS - CARVE_OUTS
keep if tier == "Total RPS"
drop tier

gen actual_rps = oblig - carve
drop oblig carve

* Using 2014 obligation for 2015
preserve
	keep if year == 2014
	replace year = 2015
	tempfile data_2015
	save "`data_2015'"
restore

* Bring in 2015 data
append using "`data_2015'"

* BRING IN ANNUAL SALES AND CALCULATE RPS OBLIGATION / TOTAL SALES
merge 1:1 state year using "`eia_annual_sales'"

gen state_rps_level = (actual_rps / total_retail_sales) * 100

*Set obligation to 0 if state not listed in RPS dataset
replace state_rps_level = 0 if _merge == 2

drop actual_rps total_retail_sales _merge

* EXPAND INTO 12 MONTHS FOR EACH STATE-YEAR
expand 12
sort state year
bys state year: gen month = _n

* BRING IN REC PRICES
merge 1:1 state year month using "`rec_state_year_month'"
assert _merge != 2
drop _merge

label var state_rps_level " State RPS level (% of retail sales, annual)"

order state year month
sort state year month
compress
save "$generated_data/state_year_month_rps_rec.dta", replace
********************************************************************************
tempsetup
capture log close
exit

