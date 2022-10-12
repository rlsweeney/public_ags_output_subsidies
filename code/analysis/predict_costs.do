/*******************************************************************************
THIS FILE ESTIMATES LIFETIME PRODUCTION
- PURPOSE IS TO GET DISCOUNTED PROFITS UNDER 1603 AND PREDICT PROFITS UNDER PTC
********************************************************************************/
local fname predict_costs

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

use $repodir/generated_data/deflators, clear
rename year firstyear
save fdeflator, replace 

*IMPORT EXTERNAL COST ESTIMATES 
** clean in `clean_bnef_cost_data.do`
use $repodir/generated_data/static_reg_data, clear
di _N
merge 1:1 facilityid using $repodir/generated_data/external_data_all, nogen keep(match master)

gen st_cost1603 = amount_funded/.3/1000000
gen st_cost1603_permw = st_cost1603/first_nameplate_capacity

gen costgoogle_permw = CostGoogle/first_nameplate_capacity

merge m:1 firstyear using fdeflator, nogen keep(match master)

foreach v of varlist costbnef_permw costsnl_permw costgoogle_permw st_cost1603_permw {
	replace `v' = `v'*gdp_deflator
}

save tempdat, replace

use tempdat, clear
keep if firstyear >= 2008 & firstyear <= 2013 

foreach v of varlist costbnef_permw costsnl_permw costgoogle_permw st_cost1603_permw {
	rename `v' c_`v'
}

keep facilityid firstyear c_*

reshape long c_ , i(facilityid) j(cvar, string)
drop if c_ == . 
sum c_, detail
global cmean = `r(mean)'
global csd = `r(sd)'

di $cmean
di $csd

use tempdat, clear
keep if firstyear >= 2008 & firstyear <= 2013 

foreach v of varlist costbnef_permw costsnl_permw costgoogle_permw st_cost1603_permw {
	gen sd_`v' = abs(`v' - $cmean)/$csd
}

sum sd*, detail

* FOR CASES WHERE WE HAVE MULTIPLE ESTIMATES, IGNORE OUTLIERS
gen cost_mw = st_cost1603_permw if sd_st_cost1603_permw < 2

egen cost_private_permw = rowmean(costbnef_permw costsnl_permw)
replace cost_private_permw = costbnef_permw if sd_costbnef_permw < 2 & sd_costsnl_permw >= 2
replace cost_private_permw = costsnl_permw if sd_costbnef_permw >= 2 & sd_costsnl_permw < 2
replace cost_private_permw = . if sd_costbnef_permw >= 2 & sd_costsnl_permw >= 2
replace cost_private_permw = costgoogle_permw if cost_private_permw == . & sd_costgoogle_permw < 2

replace cost_mw = cost_private_permw if cost_mw == .

di _N
sum cost_mw, detail

egen mf_num = group(turbinemanufacturer)
gen turbine_cap = powercurve_max_cap / 1000

gen nturbines = first_nameplate_capacity/ first_turbsize 
gen log_nturbines = log(nturbines)
gen log_cap = log(first_nameplate_capacity)

gen costsample = 1
replace costsample = 0 if multiple_grants == 1
replace costsample = 0 if state=="AK" | state=="HI"
replace costsample = 0 if public == 1
replace costsample = 0 if flag_iou_ipp ==0 // Drop commercial and industrial facilities
save regdat, replace

use regdat, clear
local tv = _N
file open myfile using "$repodir/output/estimates/N_cost_population.tex", write text replace 
file write myfile "`tv'"
file close myfile

*keep if insample // this removes 2013 plants
keep if costsample & cost_mw != . 
local tv = _N
file open myfile using "$repodir/output/estimates/N_cost_regsample.tex", write text replace 
file write myfile "`tv'"
file close myfile

keep if flag_1603 == 0
local tv = _N
file open myfile using "$repodir/output/estimates/N_cost_regsample_PTC.tex", write text replace 
file write myfile "`tv'"
file close myfile

use regdat, clear
keep if costsample 

la var log_cap "Log(Capacity)"
la var turbine_cap "Turbine Capacity"

qui{
eststo clear

eststo: reg cost_mw i.firstyear flag_1603, robust
eststo: reg cost_mw i.firstyear flag_1603 log_cap , robust
eststo: reg cost_mw i.firstyear flag_1603 log_cap i.mf_num turbine_cap , robust
		estadd local MFfes "Y", replace
eststo: reg cost_mw i.firstyear flag_1603 log_cap i.mf_num turbine_cap i.snum , robust
		estadd local MFfes "Y", replace
		estadd local statefes "Y", replace
}

esttab, keep(flag_1603 log_cap turbine_cap)	///
	s(MFfes statefes r2_a N rmse, ///
	label("Manufacturer FE" "State FE" "adj R-sq." "N" )) ///
	se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01)
	
	
*EXPORT TABLE
esttab using "$outdir/tables/cost_prediction.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(flag_1603 log_cap turbine_cap)	///
	nonotes compress booktabs b(a2) ///
	s(MFfes statefes r2_a N rmse, ///
		label("Manufacturer FE" "State FE" "adj R-sq." "N" )) ///
	nomtitles 	

* PREDICT COSTS (for cost effectiveness calculation)

use regdat, clear

qui: reg cost_mw i.firstyear flag_1603 log_cap i.mf_num turbine_cap i.snum if costsample, robust

predict cost_mw_est 

keep facilityid cost_mw* costsample

save $repodir/generated_data/cost_estimates, replace

********************************************************************************
tempsetup
capture log close
exit
