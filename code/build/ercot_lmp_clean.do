/* Read in LMP Pricing for ERCOT */
clear
local fname ercot_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global ercot "D:/LMP Data/ERCOT" // External Hard Drive
global temp  "D:/temp" //external hard drive
********************************************************************************
forval year = 2010 / 2015 {
	local counter = 0
	cd "$ercot/`year'"
	
	* Write all of CSV into a text file - cannot use macros because too manyfiles
	! dir *.csv /b/s >  all_csv_names.txt
	
	file open all_csv using all_csv_names.txt, read text
	file read all_csv f
	while r(eof) == 0 {
		qui {
			import delimited using "`f'", clear varnames(1)
			destring lmp, replace force
			
			gen hour = hh(clock(scedtimestamp, "MDYhms"))
			gen  date = date(scedtimestamp, "MDY###")
			format date %td
			
			local counter = `counter' + 1
			qui save "$temp/ercot_`counter'", replace
			file read all_csv f
		}
	}
	file close all_csv
	clear
	forval y = 1 / `counter' {
		append using "$temp/ercot_`y'.dta"
		rm "$temp/ercot_`y'.dta"
	}
	collapse (mean) lmp, by(settlement date hour) 
	
	rename settlement node_name
	
	compress
	save "$dropbox/Data/public/ISO_LMP/ERCOT/ercot_`year'.dta", replace
}
********************************************************************************
tempsetup
capture log close
exit

		