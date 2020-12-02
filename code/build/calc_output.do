* Calculate Output for each facility
clear
local fname calc_output

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global wind_data "D:/wind speed data/"
global wind_temp "D:/temp"
********************************************************************************

**************************************************
* CREATE A DATASET WITH JUST REFERENCE POWERCURVE
**************************************************
use "$generated_data/models_powercurve_xwalk.dta", clear
keep if powercurve_turbinemodel == "1.5sle"
keep powercurve_turbinemodel w*
duplicates drop
renvars w*, prefix("ref")
tempfile reference_powercurve
save "`reference_powercurve'"

************************
* CALCULATE OUTPUT
************************
cd "$wind_data"
local wind_files: dir "wind_clean" files "wind_*.dta"
local counter = 0
foreach w_file in `wind_files' {
	qui {
		use "wind_clean/`w_file'", clear
		
		* Bring in powercurve for each facility
		merge m:1 facilityid using "$generated_data/models_powercurve_xwalk.dta", keep(master matched) nogen
		
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
			cross using "`reference_powercurve'"
			gen output_refturb = 0
			forval i = 0 / 60 {
				replace output_refturb = refw`i' if wind == `i'
			}
			gen output_refturb_adjusted = (pressure_0m / temperature_2m) / (101325 / 288.15) * output_refturb
		}
		collapse (sum) output*, by(facilityid year month)
		
		compress
		local counter = `counter' + 1
		tempfile output`counter'
		save "`output`counter''"
	}
}
clear
forval y = 1 / `counter' {
	append using "`output`y''"
}
foreach var in output output_adjusted output_refturb output_refturb_adjusted {
	replace `var' = `var' / 1000
}
gen reference_turbine_capacity = 1.5
label var output "Monthly output (MWH)"
label var output_adjusted "Monthly output (MWH) adjusted for temp and pressure"
label var output_refturb "Monthly output using the modal turbine"
label var output_refturb_adjusted "Monthly output using modal turbine adj for temp and pressure"
save "$generated_data/calculated_output.dta", replace
********************************************************************************
tempsetup
capture log close
exit

