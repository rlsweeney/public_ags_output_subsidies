* Clean Raw Wind Files
clear
local fname wind_prep

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
cd "D:/wind speed data/"  // EXTERNAL HARD DRIVE
********************************************************************************
*****************************************************
/* IMPORT RAW WIND FILES TO PRODUCE TWO CLEAN FILES
	1. CLEAN WIND FILES - AT FACILITY HOURLY LEVEL
	2. WIND SPEED - AT FACILITY YEAR MONTH LEVEL
****************************************************/

* STORE ALL OF RAW WIND FILES IN A LIST AND LOOP THROUGH THEM
local csvfiles : dir "raw" files "*.csv"
local counter = 0 // allows to save wind speed files and them loop through them
di "Processing Raw Wind Files"
foreach f in `csvfiles' {

	qui {
		import delimited using "raw/`f'", clear delim(",")
	
		renvars , map(word(@[7], 1))
		drop in 1/7
		drop if pressure == "" & temperature == "" & winddirection == "" & windspeed == ""
		renvars, lower
		
		*Grab Facility ID - all chars before "-"
		local strpos = strpos("`f'", "-")
		local fid = substr("`f'", 1, `strpos' - 1)
		gen facilityid = `fid'
		
		gen date = dofc(clock(fields,"YMDhms"))
		gen year = year(date)
		gen month = month(date)
		keep if date >= td(01jan2001) & date <= td(31dec2015)
		drop date fields
		destring temperature_2m pressure_0m wind*, replace
		compress
		save "wind_clean/wind_`fid'", replace
		
		*Create Wind Speed File
		
		*Generate Covariances
		sort year month
		egen airwindcov    = corr(windspeed_80m pressure_0m),    covariance by(year month)
		egen tempwindcov   = corr(windspeed_80m temperature_2m), covariance by(year month)
		egen windvar       = corr(windspeed_80m windspeed_80m),  covariance by(year month)
		
		gen wind2 = windspeed_80m ^ 2
		gen wind3 = windspeed_80m ^ 3
	}
	collapse (count) num_wind_hours = windspeed_80m (mean) airwindcov tempwindcov temperature pressure_0m wind*, by(facilityid year month)
	
	keep wind* airwindcov tempwindcov temperature pressure_0m facilityid year month num_wind_hours
	qui compress
	local counter = `counter' + 1
	tempfile wind_speed_`counter'
	qui save "`wind_speed_`counter''"
}

* APPEND ALL OF THE TEMPORARY WIND-SPEED FILES
clear
forval y = 1 / `counter' {
	append using "`wind_speed_`y''"
}

rename (temperature_2m pressure_0m windspeed_80m winddirection_80m) ///
        (temperature airpressure wind_speed wind_direction)

la var wind_direction    "Monthly Wind Direction"
la var wind_speed        "Monthly Wind Speed  (m/s)"
la var wind2             "Monthly Wind Speed ^ 2"
la var wind3             "Monthly Wind Speed ^ 3"
label var temperature    "Monthly temperature"
label var airpressure    "Monthly air pressure"
label var tempwindcov    "Covariance between temperature and wind speed"
label var airwindcov     "Covariance between air pressure and wind speed"
label var windvar        "Windspeed Variance"
label var num_wind_hours "Number of hours of wind data in a month that was used to produce monthly means"
compress
sort facilityid year month
save "$generated_data/windspeed.dta", replace
********************************************************************************
tempsetup
capture log close
exit
