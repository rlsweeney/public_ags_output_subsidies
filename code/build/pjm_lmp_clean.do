/* Pull hourly LMP Data from PJM */
clear
local fname pjm_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global pjm         "D:\LMP Data\PJM" // External Hard Drive
global temp        "D:\temp" // External Hard Drive
global destination "$dropbox/Data/public/ISO_LMP/PJM"
********************************************************************************
cd "$pjm"
/* All of these files have the following format

hour  1     1     1    2   2   2
     lmp    mcc   mlc  lmp mcc mlc
Stata canot have duplicate variables names. so instead I will rename those variables using
a loop to create the rename that I want

so v1 v2 v3 v4 v5 v6 will become lmp1 mcc1 mlc1 lmp2 mcc2 mlc2
*/
local newnames
forval y = 1 / 24 {
	local newnames `newnames' lmp`y' mcc`y' mlc`y'
}

/* The output data-sets of this file are very large. So I am going to strip out all of the node ID
   information as a seperate data-set so the large data-set will only have node_name node_id date
   hour and lmp.
   
   For ID, I just append continously building an ID data-set to keep it as small as possible
*/
local counter_id = 0
forval year = 2009 / 2015 {
	local csv_files: dir "`year'" files "*.csv"
	
	* Memory constraint is too large. Going to save files with no id and id info seperate
	local counter = 0
	foreach f in `csv_files' {
		qui {
			import delimited using "`year'/`f'", delim(",") clear
			
			* Want all observations after "Start of Real Time LMP Data
			gen flag = _n if regexm(v1, "Date")
			qui summ flag
			drop in 1 / `=`r(max)''
			drop flag
			rename (v1-v7) (date node_id node_name voltage equipment type zone)
			destring v* node_id, replace
			
			rename (v8-v79) (`newnames')
			gen date_d = date(date, "YMD")
			
			keep date_d node_id node_name voltage equipment type zone `newnames'
			rename date_d date
			* For memory.
			drop mcc* mlc*
			duplicates drop
			*Bring LMP MCC and MLC into long format
			reshape long lmp, i(node_id date) j(hour)
			
			preserve
				keep node_id node_name voltage equipment type zone
				duplicates drop
				local counter_id = `counter_id' + 1
				if `counter_id' == 1 {
					save "$destination/pjm_node_id_info.dta", replace
				}
				else {
					append using "$destination/pjm_node_id_info.dta"
					duplicates drop
					save "$destination/pjm_node_id_info.dta", replace
				}
			restore
			keep node_id date node_name hour lmp
			local counter = `counter' + 1
			compress
			save "$temp/pjm_`year'_`counter'.dta", replace
		}
	}
	clear
	local pjm_`year': dir "$temp" files "pjm_`year'*.dta"
	foreach pjm_file in `pjm_`year'' {
		append using "$temp/`pjm_file'"
		rm "$temp/`pjm_file'"
	}
	compress
	save "$destination\pjm_`year'.dta", replace
}
********************************************************************************
tempsetup
capture log close
exit
