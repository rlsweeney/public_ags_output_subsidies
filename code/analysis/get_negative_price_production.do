/* GET PROD DURING NEGATIVE HOURS 
- uses files from match_nodes_to_plants.do

- NOTE THIS USES STATA ADOS grc1leg and egenmore
********************************************************************************/
local fname get_negative_price_production

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

use $generated_data/static_reg_data, clear
keep if firstyear > 2004 & firstyear < 2013
keep facilityid 
merge 1:1 facilityid using "$generated_data/facility_closestnode.dta", nogen keep(match)
rename my_node_iso ISO 
save facilitydata, replace

keep facilityid ISO node_name node_id
save faclist, replace

* LOAD AND SAVE A SUBSET OF THE WINDSPEED DATA FOR JUST THE YEARS WE HAVE PRICES FOR
use "$wind_data_dir\wind_all_plants.dta" if date > date("20100101","YMD"), clear
gen double eventtime = clock(fields, "YMDhms")
format eventtime %tc
gen hour = hh(eventtime)
capture drop date
gen date=dofc(eventtime)
format %td date
gen Year = year(date)
gen Month = month(date)
gen Day = day(date)

drop fields 
save windtempdat, replace


use "$generated_data/models_powercurve_xwalk.dta", clear
* this should be zero in the TWP power curve data 
replace w5 = 0 if powercurve_turbinemodel == "swt-2.3-101"
save xwalk, replace

** THIS SECTION COPIED FROM calc_output.do 
* CREATE A DATASET WITH JUST REFERENCE POWERCURVE
use xwalk, clear
keep if powercurve_turbinemodel == "1.5sle"
keep powercurve_turbinemodel w*
duplicates drop
*note this renvars command no longer used. see here https://www.statalist.org/forums/forum/general-stata-discussion/general/1560780-renvars-command
*renvars w*, prefix("ref")
rename (w*) ref=
save reference_powercurve, replace


use windtempdat, clear
merge m:1 facilityid using faclist, nogen keep(match)
		
	* Bring in powercurve for each facility
	merge m:1 facilityid using  xwalk, keep(master matched) nogen
	
	**************************************
	* CALC OUTPUT USING MATCHED POWERCURVE
	**************************************
	gen output = 0
	* Multiplying by 2 because w30 corresponds to 15 miles per hour. 
	* So if wind is 15.32 becomes 30 so then output for w30 gets selected
	gen wind = round(windspeed_80m * 2)
	
	forval i = 0 / 60 {
		replace output = w`i' if wind == `i'
	}
	gen output_adjusted  = (pressure_0m / temperature_2m) / (101325 / 288.15) * output
	
	*****************************************************
	* CALC REFERENCE OUTPUT (OUTPUT USING MODAL TURBINE)
	*****************************************************
	
	* Regular output for unmatched turbines was using modal turbine. Dont' need to calc again
	if flag_powercurve == 0 | powercurve_turbinemodel == "1.5sle" {
		gen output_refturb = output
		gen output_refturb_adjusted = output_adjusted
	}

	* FOR MATCHED FACILITIES, GOING TO BRING IN MODAL POWERCURVE AND CALCULATE OUTPUT
	else {
		cross using reference_powercurve
		gen output_refturb = 0
		forval i = 0 / 60 {
			replace output_refturb = refw`i' if wind == `i'
		}
		gen output_refturb_adjusted = (pressure_0m / temperature_2m) / (101325 / 288.15) * output_refturb
	}

	foreach var in output output_adjusted output_refturb output_refturb_adjusted {
		replace `var' = `var' / 1000
	}
	
	gen reference_turbine_capacity = 1.5
	label var output "Monthly output (MWH)"
	label var output_adjusted "Monthly output (MWH) adjusted for temp and pressure"
	label var output_refturb "Monthly output using the modal turbine"
	label var output_refturb_adjusted "Monthly output using modal turbine adj for temp and pressure"

keep facilityid hour Year Month Day ISO node_name node_id output wind /// 
			output_adjusted output_refturb output_refturb_adjusted
save outputhours, replace


use "$dropbox/Data/public/ISO_LMP/closenodes_hourly_data.dta", clear
keep if Year > 2009
gen Day = day(date)
joinby ISO node_name node_id using faclist
sort facilityid Year Month Day hour
drop mcc mlc 
replace hour = hour - 1
save longnodedat, replace


use longnodedat, clear
drop if Year == . | Month == .
merge 1:1 facilityid Year Month Day hour using outputhours, keep(match using)
gen flag_misslmp = cond(_merge <3,1,0)
replace lmp = 1 if lmp == .
capture drop lmp_l* l_out*

local outlist 0 5 15 23 25
foreach t in `outlist' {
	
	gen lmp_l`t' = cond(lmp < (-`t'),1,0)
	gen l_output_`t' = output*lmp_l`t'
	gen l_output_adj_`t' = output_adjusted*lmp_l`t'
	gen l_output_ref_`t' = output_refturb*lmp_l`t'
	gen l_output_ref_adj_`t' = output_refturb_adjusted*lmp_l`t'

}

gen monthours = 1
collapse (sum) output* l_* lmp_l* flag_misslmp monthours, by(facilityid Year Month)

save facility_negative_prod, replace


use facilitydata, clear
merge 1:m facilityid using facility_negative_prod, nogen keep(match)

gen share_l0 = lmp_l0/monthours
gen share_l23 = lmp_l23/monthours

gen output_share_l0 = l_output_0/output
gen output_share_l23 = l_output_23/output
gen output_share_l0_adj = l_output_adj_0/output_adj
gen output_share_l23_adj = l_output_adj_23/output_adj

gen misshare = flag_misslmp/monthours

rename Year year 
rename Month month
rename output_adj output_adj_new
rename output output_new
rename ISO node_ISO_new

keep facilityid year month share_* /// 
		l_output_0 l_output_23 output_new ///
		l_output_adj_0 l_output_adj_23 output_adj_new ///
		misshare monthours km_to_my_node output_share_* node_ISO_new

save "$generated_data/negative_correction.dta", replace


********************************************************************************

tempsetup
cd "$repodir" 
capture log close
exit
