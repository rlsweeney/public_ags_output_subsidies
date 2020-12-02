/* Read in 5-minute interval LMP Pricing from California (CA) ISO */
clear
local fname caiso_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global caiso     "D:/LMP Data/CAISO" // external hard drive
global temp      "D:/temp" //external hard drive
********************************************************************************
forval year = 2012 / 2015 {
	di "`year'"
	local csv_files: dir "`year'" files "*.csv"
	local counter = 0
	foreach f in `csv_files' {
		qui {
			import delimited using "`year'/`f'", clear
			
			keep opr_dt opr_hr node_id node value
			rename (node value opr_hr) (node_name lmp hour)
			drop node_id //node name is the exact same
			gen date = date(opr_dt, "YMD")
			format date %td
			drop opr_dt
			
			* DOING A COLLAPSE BY HOUR HERE TO SAVE TIME
			bys node_name date hour: egen lmp_mean = mean(lmp)
			bys node_name date hour: keep if _n == 1
			keep node_name date hour lmp_mean
			rename lmp_mean lmp
			
			compress
			local counter = `counter' + 1
			save "$temp/caiso`counter'.dta", replace
		}
	}
	clear
	forval c = 1 / `counter' {
		append using "$temp/caiso`c'.dta"
		rm "$temp/caiso`c'.dta"
	}
	order node_name date hour
	save "$dropbox\Data\public\ISO_LMP\CAISO\caiso`year'.dta", replace
	
}
********************************************************************************
tempsetup
capture log close
exit

		
		
		
		
	
