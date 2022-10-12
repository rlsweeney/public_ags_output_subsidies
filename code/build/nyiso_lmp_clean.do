/* Read in NYISO LMP Data */
clear
local fname nyiso_lmp_clean
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global nyiso "D:\LMP Data\NYISO" // External Hard Drive
global temp  "D:\temp" // External Hard Drive
********************************************************************************
* Two different node types for NYISO
local node_type_list Generator Zonal

foreach node_type in `node_type_list' {
	cd "$nyiso/`node_type' Node Data"
	
	forval year = 2009 / 2015 {
		local counter = 0
		local next_year = `year' + 1
		local files_`year': dir "`year'" files "*.csv"
		foreach f in `files_`year'' {
			qui {
				 import delimited "`year'/`f'", clear
				 gen clock = clock(timestamp,"MDYhms")
				 gen date = dofc(clock)
				 gen year = year(date)
				 format date %td
				 gen hour = hh(clock)
				 drop clock timestamp
				 
				 local counter = `counter' + 1
				 compress
				 save "$temp/nyiso_`year'_`counter'.dta", replace
			}
		}
		clear
		local nyiso_`year': dir "$temp" files "nyiso_`year'*.dta"
		foreach f in `nyiso_`year'' {
			append using "$temp/`f'"
			rm "$temp/`f'"
		}
		* Some years have part of Jan 1 nf next year
		preserve
			keep if year == `next_year'
			tempfile data_`next_year'
			save "`data_`next_year''"
		restore 
		
		* Now append the data that was saved on previous iteration		
		drop if year == `next_year'
		if `year' > 2009 {
			append using "`data_`year''"
		}
		qui tab year
		assert `r(r)' == 1
		
		* WANT DATA AT HOURLY LEVEL. TAKE AVERAGE OVER ALL PRICE VARIABLES
		collapse (mean) lmp = lbmpmwhr (firstnm) name, by(ptid date hour)
		
		rename (ptid name) (node_id node_name)
		*label var mlc      "Marginal Cost Losses ($/MWHr)"
		*label var mcc      "Marginal Cost Congestion ($/MWHr)"	
		gen type = "`node_type'"
		compress
		tempfile nyiso_`node_type'_`year'
		save "`nyiso_`node_type'_`year''"
	}
}

* NOW APPEND THE TWO DIFFERENT NODE_TYPES AND SAVE TO DROPBOX
forval year = 2009 / 2015 {
	clear
	append using "`nyiso_Generator_`year''"
	append using "`nyiso_Zonal_`year''"

	compress
	save "$dropbox\Data\public\ISO_LMP\NYISO\nyiso_`year'.dta", replace
}
********************************************************************************
tempsetup
capture log close
exit


