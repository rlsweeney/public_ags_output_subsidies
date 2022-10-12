/* Read in Hourly LMP Data from MISO */
clear
local fname miso_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global miso "D:/LMP Data/MISO" // External Hard Drive
global temp "D:/temp" // External Hard Drive
********************************************************************************

* Make a list of h1-h24 - will be used to name hourly variables for reshape
local hour_list 
forval y = 1 / 24 {
	local hour_list `hour_list' h`y'
}
* Here is a list of MISO variables that we will use to rename
local miso_variables node_name type value `hour_list'

forval year = 2008 / 2015 {
	
	local counter = 0
	local csv_files: dir "raw/`year'" files "*.csv"
	
	* LOOP THROUGH EVERY FILE IN THAT YEAR'S FOLDER
	foreach f in `csv_files' {
		qui {
			import delimited using "raw/`year'/`f'", delim(",") clear
						
			* 2008 - 2011 STARTS AT ROW 4
			if inrange(`year', 2008, 2011) {
				drop in 1 / 4	
				rename (_all) (`miso_variables')
				gen date = date(substr("`f'", 1, 8), "YMD")
			}
			
			* 2012- 2015 VARIABLES START IN ROW 1 and include a date variable
			else {
				rename (_all) (market_day `miso_variables')
				gen date = date(market_day, "MDY")
				drop market_day
			}
			destring h*, replace
			
			* BRING HOUR INTO LONG FORMAT
			reshape long h, i(node_name type value date) j(hour)
			
			* Bring Data (LMP, MCC, MLC) into seperate columns
			reshape wide h, i(node_name type date hour) j(value) string
			rename (hLMP hMCC hMLC) (lmp mcc mlc)

			local counter = `counter' + 1
			compress
			save "$temp/miso_`year'_`counter'.dta", replace
		}
	}
	
	* APPEND ALL FILES TO CREATE ONE DATASET FOR EACH YEAR
	clear
	local miso_`year': dir "$temp" files "miso_`year'*.dta"
	foreach f in `miso_`year'' {
		append using "$temp/`f'"
		rm "$temp/`f'"
	}
	compress
	save "$dropbox/Data/public/ISO_LMP/MISO/miso_`year'.dta", replace
}
********************************************************************************
tempsetup
capture log close
exit

