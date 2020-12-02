* Put all data together to create final panels
clear
local fname build_final_panel

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
cd "$generated_data"
*********************************************
* CREATE A LIST OF FACILITIES IN WIND DATA 
*********************************************
use "windspeed.dta", clear
keep facilityid
duplicates drop
tempfile facilities_with_wind
save "`facilities_with_wind'"
********************************************************************************
*					DATASET AT THE FACILITY LEVEL (STATIC)
********************************************************************************

* START WITH FACILITIES THAT CONTAIN BOTH 860 AND 923 DATA
use "eia_static.dta", clear
drop manufacturer_eia model_eia // non-standardized versions. duplicates and typos

* Bring in Standardized Manufacturer and Model Name
merge 1:1 facilityid using "standardized_turbine_list.dta", /// 
keep(master matched) nogen keepusing(turbinemanufacturer turbinemodel)

* Bring in Powercurve Static Variables
merge 1:1 facilityid using "models_powercurve_xwalk.dta", ///
keep(master matched) keepusing(flag_powercurve powercurve_turbinemodel powercurve_max_cap) nogen

* Create an indicator for facilities with wind data
merge 1:1 facilityid using "`facilities_with_wind'"
assert _merge != 2
gen flag_in_wind = cond(_merge == 3, 1, 0)
drop _merge
label var flag_in_wind "Indicator - Facility has Wind Data"

* Merge in AWEA Information
merge 1:1 facilityid using "awea.dta", keep(master matched)
gen flag_in_awea = cond(_merge == 3, 1, 0)
drop awea_manufacturer awea_model _merge

* Merge in 1603 Information
merge 1:1 facilityid using "1603_info.dta", nogen keep(master matched)

* Merge in SNL data
merge 1:1 facilityid using "snl_data.dta", nogen keep(master matched)

qui compress
save "final_panel_static.dta", replace
********************************************************************************
*			DATA-SET AT FACILITYID - YEAR - MONTH LEVEL (DYNAMIC)
********************************************************************************

* CREATING SEPERATE DATASET OF ONLY DYNAMIC VARS  BUT NEED STATE TO MERGE IN RPS/RECS
keep facilityid state

* EIA 
merge 1:m facilityid using "eia_dynamic.dta", nogen keep(master matched)

* WIND SPEEDS
merge 1:1 facilityid year month using "windspeed.dta", nogen keep(master matched)

* CALCULATED OUTPUT BASED ON WIND SPEED
merge 1:1 facilityid year month using "calculated_output.dta", nogen keep(master matched)

********************************************************************************

* MERGE REC AND RPS BY STATE-YEAR-MONTH
merge m:1 state year month using "state_year_month_rps_rec.dta", nogen keep(master matched)

* BRING IN OUT_OF_STATE EXPECTED REC PRICE
merge m:1 state year month using "recs_out_of_state_adjustment.dta", nogen keep(master matched)

* BRING IN EIA 826 AVERAGE STATE ELECTRICTY PRICES MONTHLY
merge m:1 state year month using "EIA_826.dta", nogen keep(master matched)

sort facilityid year month
order facilityid year month
compress
save "final_panel_dynamic.dta", replace
********************************************************************************
tempsetup
capture log close
exit
