/* READ IN EIA PROPOSED PLANT DATA */
********************************************************************************
local fname eia_proposal_data_prep 

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"
tempsetup

log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

global eia860 "$dropbox/Data/public/eia/eia_860"

********************************************************************************
*								PROGRAMS
********************************************************************************
* PROGRAM TO STANDARDIZE ID VARS ACROSS ALL FILES
capture program drop standardize_id_variables
program define standardize_id_variables

	qui {
		renvars, lower
		renvars, subs("_" "")

		capture rename utilcode    operatorid
		capture rename utilitycode operatorid
		capture rename utilityid   operatorid
		capture rename utilityname operatorname
		capture rename utilname    operatorname
		capture rename eiautilitycode operatorid

		capture rename plntcode  facilityid
		capture rename plantid   facilityid
		capture rename plantcode facilityid
		capture rename plntname  facilityname
		capture rename plantname facilityname

		capture rename gencode     genid
		capture rename generatorid genid
		capture rename generatorcode genid

	}
end

capture program drop replacevar
program define replacevar
	syntax varlist(max = 1), oldval(str) newval(str)
	
	replace `varlist' = "`newval'" if `varlist' == "`oldval'"
end

capture program drop update_mover
program define update_mover
	replacevar primemover, oldval("ST") newval("Steam Turbine")
	replacevar primemover, oldval("GT") newval("Gas Turbine")
	replacevar primemover, oldval("IC") newval("Internal Combustion Engine")
	replacevar primemover, oldval("CA") newval("Combined Cycle - Steam")
	replacevar primemover, oldval("CT") newval("Combined Cycle - Combustion")
	replacevar primemover, oldval("CS") newval("Combined Cycle - Single Shaft")
	replacevar primemover, oldval("CC") newval("Combined Cycle - Total Unit") 
	replacevar primemover, oldval("HC") newval("Hydraulic Turbine")
	replacevar primemover, oldval("HY") newval("Hydraulic Turbine")
	replacevar primemover, oldval("PS") newval("Hydraulic Turbine - Reversible")
	replacevar primemover, oldval("BT") newval("Binary Cycle Turbines")
	replacevar primemover, oldval("PV") newval("Photovoltaic")
	replacevar primemover, oldval("WT") newval("Wind Turbine")
	replacevar primemover, oldval("CE") newval("Compressed Air Storage")
	replacevar primemover, oldval("FC") newval("Fuel Cell")
	replacevar primemover, oldval("OT") newval("Other")
	replacevar primemover, oldval("WS") newval("Wind Turbine")
	replacevar primemover, oldval("BA") newval("Energy Storage, Battery")
	replacevar primemover, oldval("CP") newval("Energy Storage, Solar")
	replacevar primemover, oldval("FW") newval("Energy Storage, Flywheel")
	replacevar primemover, oldval("HA") newval("Hydrokinetic, Axial Flow")
	replacevar primemover, oldval("HB") newval("Hydrokinetic, Wave Buoy")
end

* THIS PROGRAM CREATES A FLAG FOR TWO FUNDAMNETALLY DIFFERENT TECHNOLOGIES
capture program drop flag_diff_tech
program define flag_diff_tech

	* Create flag for facilities with two (fundamentally) differnet primemover technologies)
	egen num_technology = nvals(primemover), by(facilityid eia860yr)
	gen two_technologies = cond(num_technology > 1, 1, 0)

	* Now only keep those with two fundamentally different technologies
	bys facilityid eia860yr: gen numobs = _N
	bys facilityid eia860yr: egen total_gas = ///
							 total(inlist(primemover, "Combined Cycle - Combustion", ///
													  "Combined Cycle - Single Shaft", ///
													  "Combined Cycle - Steam", ///
													  "Combined Cycle - Total Unit", ///
													  "Gas Turbine", ///
													  "Steam Turbine", ////
													  "Internal Combustion Engine"))
	replace two_technologies = 0 if num_technology > 1 & total_gas == numobs	
	drop numobs total_gas num_technology
end
********************************************************************************
*						GET EIA PLANT DATA
********************************************************************************
**********************
* FACILITY LEVEL DATA
**********************
forval y = 1990 / 2016 {
	di "`y'"
	qui cd "$eia860/eia860`y'"
	*****IMPORT DATA - DIFF YEARS, DIFF FILE FORMATS *******
	local twodigit = substr("`y'", 3, .)
	clear
	if `y' < 1992      import excel using  "PlantY`twodigit'.xls", firstrow
	else if `y' < 1995 import excel using "PLNT`twodigit'.xls", firstrow 
	else if `y' < 1998 import excel using "PLANTY`twodigit'.xls", firstrow
	else if `y' <= 2000 import excel using "Plant`y'.xls", firstrow
	if inrange(`y', 2001, 2003) import delimited using "PLANTY`twodigit'", clear
	else if `y' > 2003 {
		local start_2nd_row cellrange(A2)
		if inrange(`y', 2004, 2009)      import excel using  "PlantY`twodigit'.xls", firstrow
		else if `y' == 2010              import excel using  "PlantY`y'.xls", firstrow
		else if inrange(`y', 2011, 2012) import excel using  "PlantY`y'.xlsx", firstrow `start_2nd_row'
		else                             import excel using  "2___Plant_Y`y'.xlsx", firstrow `start_2nd_row'
	}
	qui {
		standardize_id_variables
		
		capture rename plntzip zip
		capture rename plantzipcode zip
		capture rename zip5 zip
		capture rename plantzip5 zip
		capture rename plantzipcd zip
		capture rename plntstate state
		capture rename plantstate state
		capture rename plntst state
	
		destring zip, replace
		if `y' != 2000 {
			keep operatorid facilityid facilityname state zip 
		}
		* 2000 doesn't have facilityname
		else {
			keep operatorid facilityid state zip 
		}
		gen eia860yr = `y'	
		
		tempfile plant`y'
		save "`plant`y''"
	}
}
clear 
forval y = 1990 / 2016 {
	append using "`plant`y''"
}
drop operatorid
*TAKE MOST RECENT FACILITY NAME AND FILL IN FOR ALL YEARS
duplicates drop
bys facilityid (eia860yr): gen fac_name = facilityname[_N]
bys facilityid : egen common_fac_name = mode(facilityname), minmode missing
replace fac_name = common_fac_name if fac_name == ""
drop facilityname common_fac_name
rename fac_name facilityname

* Get Plant Identifiers
bys facilityid (eia860yr): keep if _n == _N
drop eia860yr
duplicates drop
save "facilities.dta", replace
********************************************************************************
*							ACTUAL GENERATION
********************************************************************************
forval y = 1990 / 2016 {
	clear
	qui cd "$eia860/eia860`y'"
	di "`y'"
	
	local twodigit = substr("`y'", 3, .)
	local st_two cellrange(A2)

	
	if `y' < 1992       import excel using "GENTYPE3Y`twodigit'.xls", clear firstrow
	else if `y' < 1995  import excel using "TYPE3`twodigit'.xls", clear firstrow
	else if `y' < 1997  import excel using "TYPE3Y`twodigit'.xls", clear firstrow
	else if `y' == 1997 import excel using "GENERTOR.xls", clear firstrow
	else if `y' == 1998  import excel using "ExistingGenerators`y'", clear firstrow sheet("`y' Existing Generators")
	else if `y' < 2001  import excel using "ExistingGenerators`y'", clear firstrow sheet("Existing Generators")
	else if inrange(`y', 2001, 2003) import delimited using "GENY`twodigit'", clear		
	else if inrange(`y', 2004, 2008) import excel using "GenY`twodigit'.xls", firstrow
	else if `y' == 2009         import excel using "GeneratorY`twodigit'.xls", firstrow sheet("Exist") 
	else if `y' == 2010         import excel using "GeneratorsY`y'.xls", firstrow sheet("Exist")
	else if `y' == 2011         import excel using "GeneratorY`y'.xlsx", firstrow `st_two' sheet("operable")
	else if `y' == 2012         import excel using "GeneratorY`y'.xlsx", firstrow `st_two' sheet("Operable")
	else                        import excel using "3_1_Generator_Y`y'.xlsx", firstrow `st_two' sheet("Operable")

	qui {
		standardize_id_variables
		
		capture rename nameplate nameplate_capacity
		capture rename existingnameplate nameplate_capacity
		capture rename nameplatecapacitymw nameplate_capacity	
		capture rename (insvmonth insvyear) (operatingmonth operatingyear)
		capture rename (inservicemonth inserviceyear) (operatingmonth operatingyear)
		capture rename (inservmth inservyr) (operatingmonth operatingyear)

	
		gen eia860yr = `y'
		
		local destring_vars nameplate_capacity operatingmonth operatingyear facilityid eia860yr 
		destring `destring_vars', replace
		
		keep `destring_vars' genid primemover
		
		tempfile geni`y'
		qui save "`geni`y''"
	}
}
clear 
forval y = 1990 / 2016 {
	di "`y'"
	append using "`geni`y''"
}

/* Found out that some generators don't come online until ex 1999
   but are in data earlier with all zeros. delete those */
drop if nameplate_capacity == 0 & operatingmonth == 0 & operatingyear == 0

* Clean Prime Mover
update_mover

* FLAG DIFFERENT TECHNOLOGIES
flag_diff_tech

* STARTING IN 2001, IT WAS IN MEGAWATTS
replace nameplate_capacity = nameplate_capacity / 1000 if eia860yr < 1998

bys facilityid eia860yr: egen primemover_mode = mode(primemover), missing minmode
bys facilityid eia860yr: gen num_gens = _N

bys facilityid: egen totalwind = total(regexm(primemover, "Wind"))
gen wind_tech = cond(totalwind >=1 , 1,0)
drop totalwind 

/* For those with wind only keep those generators */
keep if wind_tech == 0 | regexm(primemover, "Wind")


* SOME MONTHS AND YEARS ARE FLIPPED
gen flag = cond(operatingmonth > 1000, 1, 0)
gen temp = operatingmonth
replace operatingmonth = operatingyear if flag
replace operatingyear = temp if flag
drop temp flag
		 
* TAKE MAX CAPACITY ACROSS YEARS
collapse (sum) nameplate_capacity (firstnm) wind_tech two_technologies num_gens primemover  ///
(min) operatingyear operatingmonth, by(facilityid eia860yr)

* CLEAN SOME DATES
replace operatingmonth = . if operatingmonth == 88 | operatingmonth == 99
replace operatingyear = . if operatingyear == 88 | operatingyear == 99

rename nameplate_capacity existing_capacity
compress
save "current_plants.dta", replace
********************************************************************************
* 						PROPOSED GENERATORS
********************************************************************************
* SPLIT INTO TWO PIECES
capture program drop proposed_vars
program define proposed_vars
	capture rename nameplate proposed_capacity
	capture rename nameplatecapacitymw proposed_capacity
	capture rename proposednameplate proposed_capacity
	
	capture rename status proposed_status
	capture rename proposedstatus proposed_status
	
	capture rename orgmnth proposed_month
	capture rename orgmonth proposed_month
	capture rename orgyear proposed_year
	capture rename effectivemonth proposed_month
	capture rename effectiveyear proposed_year
end


* TWO SHEETS: PROPOSED GENERATORS AND CANCELLED - INDEFINITELY POSTPONED
forval y = 1998 / 1999 {
	di "`y'"
	qui cd "$eia860/eia860`y'"
	import excel using "ProposedGenerators`y'.xls", sheet("Proposed Generators") firstrow clear
	qui standardize_id_variables
	qui proposed_vars	
	keep facilityid operatorid genid ///
	     primemover proposed_capacity proposed_status proposed_month proposed_year	
		 
	gen eia860yr = `y'
	tempfile gens_pr_`y'
	save "`gens_pr_`y''"
}

forval y = 1998 / 1999 {
	di "`y'"
	qui cd "$eia860/eia860`y'"
	if `y' == 1998      local sheet = "Canceled Indef Postponed"
	else if `y' == 1999 local sheet = "Canceled - Indef Posponed"
	
	import excel using "ProposedGenerators`y'.xls", sheet("`sheet'") firstrow clear
	qui standardize_id_variables
	qui proposed_vars	
	keep facilityid operatorid genid ///
	     primemover proposed_capacity proposed_month proposed_year	
	gen proposed_status = "Cancelled/Indefinitely Postponed"
	
	gen eia860yr = `y'
	
	tempfile gens_re_`y'
	save "`gens_re_`y''"
}

*****************
* COMBINE ABOVE
*****************
clear
forval y = 1998 / 1999 {
	append using "`gens_re_`y''"
	append using "`gens_pr_`y''"
}

* CLEAN SOME DATES
gen flag = cond(proposed_month > 1000, 1, 0)
gen temp = proposed_month
replace proposed_month = proposed_year if flag
replace proposed_year = temp if flag
drop temp flag

tempfile gen_1998_1999
save "`gen_1998_1999'"

*******************
* 2000  - 2016
*******************
global st_two cellrange(A2) firstrow
forval y = 2000 / 2016 {
	clear
	di "`y'"
	qui cd "$eia860/eia860`y'"
	
	if `y' < 2001 import excel using "ProposedGenerators`y'.xls", firstrow clear
	
	
	else if inrange(`y', 2001, 2008) { //seperate file

		*****IMPORT DATA - DIFF YEARS, DIFF FILE FORMATS *******
		local twodigit = substr("`y'", 3, .)
		if inrange(`y', 2001, 2003) import delimited using "PRGENY`twodigit'"
		else                        import excel using  "PRGenY`twodigit'.xls", firstrow
	}
	else {
		local twodigit = substr("`y'", 3, .)
		clear
		
		if `y' == 2009      import excel using "GeneratorY`twodigit'.xls", sheet("Prop") firstrow
		else if `y' == 2010 import excel using "GeneratorsY`y'.xls", sheet("Prop") firstrow
		else if `y' == 2011 import excel using "GeneratorY`y'.xlsx",  sheet("proposed") $st_two
		else if `y' == 2012 import excel using "GeneratorY`y'.xlsx",  sheet("Proposed") $st_two
		else                import excel using "3_1_Generator_Y`y'.xlsx", sheet("Proposed") $st_two
	}
	qui standardize_id_variables
	capture drop if regexm(operatorid, "NOTE")  // so operatorid can be destringed
	qui proposed_vars
	
	keep facilityid operatorid genid primemover proposed_capacity proposed_status proposed_month proposed_year
	qui destring operatorid proposed_year proposed_month, replace
	gen eia860yr = `y'
	
	* All Missing so treated as numeric - screwing up append
	if `y' == 2001 {
		gen prime_move = ""
		drop primemover
		rename prime_move primemover
	}
	
	tempfile proposed_`y'
	qui save "`proposed_`y''"
}
clear
forval y = 2000 / 2016 {
	di "`y'"
	append using "`proposed_`y''"
}
append using "`gen_1998_1999'"

drop operatorid

* Clean Prime Mover Codes
update_mover

replacevar proposed_status, oldval("IP") newval("Cancelled/Indefinitely Postponed")
replacevar proposed_status, oldval("TS") newval("Construction Complete, but not in operation")
replacevar proposed_status, oldval("P") newval("Planned but Reg. approvals not initiated")
replacevar proposed_status, oldval("L") newval("Reg. approvals pending")
replacevar proposed_status, oldval("T") newval("Reg approvals recieved, but not under construction")
replacevar proposed_status, oldval("U") newval("Under Construction. <= 50 % complete")
replacevar proposed_status, oldval("V") newval("Under Constructions. > 50 % complete")
replacevar proposed_status, oldval("OT") newval("Other")

order facilityid eia860yr
sort facilityid eia860yr


flag_diff_tech
* Make a variable that tracks if the facility has wind_capability
bys facilityid: egen totalwind = total(regexm(primemover, "Wind"))
gen wind_tech = cond(totalwind >=1 , 1,0)
drop totalwind

foreach var in proposed_status primemover {
	bys facilityid eia860yr: egen `var'_mode = mode(`var'), missing minmode
}


/* For those with wind only keep those generators */
keep if wind_tech == 0 | regexm(primemover, "Wind")

bys facilityid eia860yr: egen proposed_year_mode = mode(proposed_year), missing minmode
bys facilityid eia860yr: egen proposed_month_mode = mode(proposed_month), missing minmode
drop proposed_year proposed_month

bys facilityid eia860yr: gen proposed_gens = _N

collapse (firstnm) *_mode two_technologies wind_tech proposed_gens (sum) proposed_capacity, by(facilityid eia860yr)
renvars *_mode, subst("_mode" "")


replace proposed_status = "Cancelled/Indefinitely Postponed" if proposed_status == "CN"

label var proposed_status      "Proposal Status"
label var primemover           "Type of Power"
label var wind_tech            "Facility has wind generation capability"
label var two_technologies     "Facility has >=2 distinct technologies"

sort facilityid eia860yr
order facilityid eia860yr
compress
save "proposed_plants.dta", replace


********************************************************************************
* COMBINE OPERATING AND PROPOSED DATA
********************************************************************************


******************************
* CURRENT PLANTS
******************************
use "current_plants.dta", clear
*keep if wind_tech == 1

bys facilityid: egen first_yr_in_oper_data = min(eia860yr)
bys facilityid: egen last_yr_in_oper_data = max(eia860yr)
bys facilityid: egen primemover_mode = mode(primemover), minmode missing

bys facilityid: egen first_yr_oper = min(operatingyear)
bys facilityid: egen first_mnth_oper = min(operatingmonth)

* Joe wants min, max, and mode capacity
bys facilityid: egen min_capacity =  min(existing_capacity)
bys facilityid: egen max_capacity =  max(existing_capacity)
bys facilityid: egen mode_capacity =  mode(existing_capacity), minmode missing

bys facilityid: egen min_gens =  min(num_gens)
bys facilityid: egen max_gens =  max(num_gens)

bys facilityid: egen has_wind = max(wind_tech)
bys facilityid: egen mult_tech = max(two_technologies)


keep facilityid min_gens max_gens min_capacity max_capacity mode_capacity  first_yr_in_oper_data ///
     last_yr_in_oper_data primemover_mode first_yr_oper first_mnth_oper has_wind mult_tech 

duplicates drop

label var min_gens "Min # of Generators reported at Facility"
label var max_gens "Max # of Generators reported at Faciity"
label var has_wind "Has Some Wind Technology"
label var mult_tech "Multiple Technology present"
label var first_yr_in_oper_data "First Year in 860 Existing/Operating Data"
label var last_yr_in_oper_data "Last Year in 860 Existing/Operating Data"

label var first_yr_oper   "First Year of Operation"
label var first_mnth_oper "First Month of Operation"

label var min_capacity "Minimum Capacity over years"
label var max_capacity "Max Capacity over years"
label var mode_capacity "Modal Capacity over years"

label var primemover_mode "Modal Technology"

tempfile wind_actual
save "`wind_actual'"
********************************************************************************
*								PROPOSED PLANTS
********************************************************************************
use "proposed_plants.dta", clear
bys facilityid: egen proposed_primemover = mode(primemover), minmode missing
drop primemover

bys facilityid: egen has_wind = max(wind_tech)
bys facilityid: egen mult_tech = max(two_technologies)

drop wind_tech two_technologies

ren eia860yr eia860_proposal_year
label var eia860_proposal_year "Year of 860 Proposed Data"

tempfile wind_proposed
save "`wind_proposed'"
********************************************************************************
use "`wind_actual'"

merge 1:m facilityid using "`wind_proposed'"
sort facilityid eia860_proposal_year

gen was_proposed = 0
replace was_proposed = 1 if inlist(_merge, 3, 2)

gen was_built = 0 
replace was_built = 1 if inlist(_merge, 1, 3)

gen proposed_and_built = was_proposed*was_built

drop _merge

by facilityid: egen last_eia860_proposal_year = max(eia860_proposal_year)

* BRING IN FACILITY NAME / STATE
merge m:1 facilityid using "facilities.dta", keep(master matched) nogen

order facilityid eia860_proposal_year last_eia860_proposal_year proposed_year ///
	first_yr_oper proposed_and_built was_proposed was_built has_wind mult_tech ///
	proposed_status proposed_primemover facilityname state zip 

compress

save "$repodir/generated_data/eia860_proposed_and_operating.dta", replace

cd "$repodir"
	
********************************************************************************
tempsetup
capture log close
exit
