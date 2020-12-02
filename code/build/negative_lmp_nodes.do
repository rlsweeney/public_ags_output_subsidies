/* AGGREGATE ISO DATA AND GET NEGATIVE LMP SHARES BY NODE
-This code calculates fraction per node-year-month below 0 and below - 23
- Changed to just read in years 2011 - 2014. 
	- these are the only years of our sample where we observe every ISO
********************************************************************************/
local fname negative_lmp_nodes

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

global lmp_data "$dropbox/Data/public/ISO_LMP"
global output "$repodir/generated_data"

****************************************************************************************************
*			CALCULATE FRACTION OF NODE-YEAR-MONTH WITH NEGATIVE PRICES FOR EACH ISO
****************************************************************************************************
/* The following program is used to calculate the fraction of node hours in a month that
   are below 0 and - 23. It also calculates median and mean prices for LMP
   
   Some ISO have node name as the identifer and some have id. The input parameter specifices which
   to use
*/
capture program drop calc_fractions
program define calc_fractions
	args id_var
	qui {
		gen month = month(date)
		gen year = year(date)
		*Make sure there is only a single year
		qui tab year
		assert `r(r)' == 1
		
		bys `id_var' year month: gen total_obs = _N
		foreach lmp_val in 0 23 {
			bys `id_var' year month: egen count_below_`lmp_val' = total(lmp < `= -1 * `lmp_val'')
			gen fract_below_`lmp_val' = count_below_`lmp_val' / total_obs
		}
		assert count_below_23 <= count_below_0
		
		foreach stat in mean median {
			bys `id_var' year month: egen lmp_`stat' = `stat'(lmp)
		}
	}
		
end

**********************************************
* PJM - Node name is not unique. ID is unique
**********************************************
forval year = 2011 / 2015 {
	di "`year'"
	qui {
		use "$lmp_data/PJM/pjm_`year'.dta", clear
		
		calc_fractions node_id
		* Rich wants to know which ID has the most obs inside each node name
		bys node_name node_id year month: gen node_id_obs = _N
		keep node_id node_name year month fract_below* lmp_mean lmp_median node_id_obs
		bys node_id node_name year month: keep if _n == 1
		drop if node_id == .
		
		tempfile pjm_`year'
		save "`pjm_`year''"
	}
}
clear
forval year = 2011 / 2014 {
	append using "`pjm_`year''"
}

* MAKE A NOTE OF WHICH NODE ID INSIDE NODE_NAME HAS MOST DATA
bys node_name node_id: egen total_node_id_obs = total(node_id_obs)
bys node_name: egen node_with_most = max(total_node_id_obs)
gen node_with_most_flag = cond(total_node_id_obs == node_with_most, 1, 0)
label var node_with_most_flag "Node ID with the most observations inside Node_name"
drop total_node_id_obs node_with_most node_id_obs

gen iso = "PJM"
order node_id node_name month year
sort node_id node_name year month
compress
save "$output/pjm_negative_lmp.dta", replace

*********
* ERCOT
**********
forval year = 2011 / 2014 { 
	di "`year'"
	use "$lmp_data/ERCOT/ercot_`year'.dta", clear
	
	calc_fractions node_name
	keep node_name year month fract_below* lmp_mean lmp_median
	bys node_name year month: keep if _n == 1
	tempfile ercot_`year'
	save "`ercot_`year''"	
}
clear
forval year = 2011 / 2014 {
	append using "`ercot_`year''"
}
gen iso = "ERCOT"
save "$output/ercot_negative_lmp.dta",replace

*********
* MISO
*********
forval year = 2011 / 2014 { 
	di "`year'"
	use "$lmp_data/MISO/miso_`year'.dta", clear
	
	calc_fractions node_name
	keep node_name type year month fract_below* lmp_mean lmp_median
	bys node_name month year: keep if _n == 1
	tempfile miso_`year'
	save "`miso_`year''"
}
clear
forval year = 2011 / 2014 {
	append using "`miso_`year''"
}
gen iso = "MISO"
compress
save "$output/miso_negative_lmp.dta", replace
	
******************************
* NEISO - has ID but node
******************************
forval year = 2011 / 2014 { 
	di "`year'"
	qui {
		use "$lmp_data/NEISO/neiso_lmp_`year'.dta", clear
		calc_fractions node_name
		keep node_name type year month fract_below* lmp_mean lmp_median
		bys node_name year month: keep if _n == 1
		tempfile neiso_`year'
		save "`neiso_`year''"
	}
}
clear
forval year = 2011 / 2014 {
	append using "`neiso_`year''"
}
gen iso = "NEISO"
compress
save "$output/neiso_negative_lmp.dta", replace

********************************************
* NYISO - has ID but node name is unique
********************************************
forval year = 2011 / 2014 { 
	di "`year'"
	qui {
		use "$lmp_data/NYISO/nyiso_`year'.dta", clear
		calc_fractions node_name
		keep node_name year month fract_below* lmp_mean lmp_median type
		* Faster than duplicates drop
		bys node_name year month: keep if _n == 1
		tempfile nyiso_`year'
		save "`nyiso_`year''"
	}
}
clear
forval year = 2011 / 2014 {
	append using "`nyiso_`year''"
}
gen iso = "NYISO"
compress
save "$output/nyiso_negative_lmp.dta", replace

*******************************
* CAISO - NODE_NAME IS UNIQUE
* - 2009 data looks incomplete. starting in 2010
*******************************
forval year = 2011 / 2014 { 
	di "`year'"
	qui {
		use "$lmp_data/CAISO/caiso`year'.dta", clear
		calc_fractions node_name
		keep node_name year month fract_below* lmp_mean lmp_median
		* Faster than duplicates drop
		bys node_name year month: keep if _n == 1
		tempfile caiso_`year'
		save "`caiso_`year''"
	}
}
clear
forval year = 2011 / 2014 {
	append using "`caiso_`year''"
}
gen iso = "CAISO"
compress
save "$output/caiso_negative_lmp.dta", replace

********************************************************************************
tempsetup
capture log close
exit
