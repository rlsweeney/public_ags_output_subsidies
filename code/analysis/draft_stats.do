* SUMMARY NUMBERS FOR DRAFT
********************************************************************************
local fname draft_stats

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup
* this code uses tabout
//ssc install tabout

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
qui{ 

clear 
gen stat_description = ""
gen stat_value = ""
save statdat, replace

/* GET PLANT COUNTS */
use $repodir/generated_data/static_reg_data, clear
keep if insample_covars 
keep if firstyear > 2004 & firstyear < 2013
local ts = _N
clear 
set obs 1
gen stat_description = "N_total_sample" 
gen stat_value = "`ts'"
append using statdat
save statdat, replace

/*GET TREATMENT EFFECT IN PERCENT TERMS */
estimates use  "$outdir/estimates/rd_main_spec.ster" //IV estimate
local rd_teffect = _b[flag_1603]

estimates use  "$outdir/estimates/match_main_spec.ster" //IV estimate
local match_teffect = _b[flag_1603]

use $repodir/generated_data/panel_reg_data, clear
keep if insample_covars & year > 2008 & age >= 12
sum capacity_factor
local cf_all = round(`r(mean)',.01)

sum capacity_factor if flag_1603 == 1
local cf_1603  = float(round(`r(mean)',.01))

sum capacity_factor if flag_1603 == 0
local cf_ptc = round(`r(mean)',.01)

clear 
set obs 7
gen stat_description = "rd_estimate"
local tk = -1*round(`rd_teffect',.01)
gen stat_value = substr("`tk'",1,5)

replace stat_description = "match_estimate" if _n ==2
local tk = -1*round(`match_teffect',.01)
replace stat_value = substr("`tk'",1,5)  if _n ==2

*DEFINE CHANGES RELATIVE TO 1603 OBSERVED CAPACITY FACTORS. 
replace stat_description = "rd_estimate_pct" if _n ==3
local tk = -1*round(100*`rd_teffect'/`cf_1603')
replace stat_value = substr("`tk'",1,5)  if _n ==3

replace stat_description = "match_estimate_pct" if _n ==4
local tk = -1*round(100*`match_teffect'/`cf_1603')
replace stat_value = substr("`tk'",1,5) if _n ==4

replace stat_description = "avg_cf" if _n ==5
local tk =  round(`cf_all',.01)
replace stat_value = substr("`tk'",1,5) if _n ==5

replace stat_description = "avg_cf_1603" if _n ==6
local tk = round(`cf_1603' +.01,.01)
replace stat_value = substr("`tk'",1,5) if _n ==6

replace stat_description = "avg_estimate" if _n ==7
local tk = -1*round((`rd_teffect' + `match_teffect')/2,.01)
replace stat_value = substr("`tk'",1,5) if _n ==7

append using statdat
save statdat, replace

qui: use statdat, clear
qui: local ns = _N
}

forval i = 1/`ns' {
	local td = stat_description[`i']
	local tv = stat_value[`i']
	di "`td'  =   `tv'"

	file open myfile using "$repodir/output/estimates/stat_`td'.tex", write text replace 
	file write myfile "`tv'"
	file close myfile
}

********************************************************************************
tempsetup
capture log close
exit

