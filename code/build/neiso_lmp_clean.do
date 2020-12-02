/* Read in LMP Data from New England ISO */
clear
local fname neiso_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global neiso "D:/LMP Data/NEISO" // external hard drive
global temp  "D:/temp" //external hard drive
********************************************************************************

cd "$neiso"
forval year = 2009 / 2015 {
	local csv_files: dir "`year'" files "*.csv"
	local counter = 0
	* Import every file in folder Y
	foreach f in `csv_files' {
		qui import delimited using "`year'/`f'", delim(",")  clear
		qui {
			drop v1
			drop in 1 / 4
			rename (v2-v10) (date hour node_id node_name type lmp mec mcc mlc)
			drop if regexm(node_name, "String") | regexm(date, "lines") | regexm(date, "Date")
			
			gen d = date(date, "MDY")
			format d %td
			drop date
			rename d date
			local counter = `counter' + 1
			save "$temp/neiso`counter'.dta", replace
		}
	} 
	clear
	forval y = 1 / `counter' {
		append using "$temp/neiso`y'.dta"
		rm "$temp/neiso`y'.dta"
	}
	
	la var lmp "Locational Marginal Price ($)"
	la var mec "Marginal Energy Component ($)"
	la var mcc "Marginal Congestion Component ($)"
	la var mlc "Marginal Loss Component ($)"
	
	*02 is for daylights savings time. turn it into a number in order to destring
	cap replace hour = "25" if hour == "02X"
	destring hour node_id lmp mec mcc mlc, replace
	
	* For Memory 
	drop mec mcc mlc
	
	/* Want to keep node name, not ID (to match other ISO). Some ID have multiple node names *(typos)
	   Just pick one and keep only the name as an identifier */
	bys node_id: gen node_last = node_name[_N]
	
	* Make sure number of ID match number of nodes
	qui unique node_id
	local unique_id = `r(sum)'
	qui unique node_last
	assert `r(sum)' == `unique_id'
	
	drop node_name
	rename node_last node_name
	compress
	save "$dropbox/Data/ISO_LMP/NEISO/neiso_lmp_`year'.dta",replace
}
********************************************************************************
tempsetup
capture log close
exit
