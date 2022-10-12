/*******************************************************************************
THIS FILE IMPORTS PRICE INDICES
********************************************************************************/
local fname import_deflators

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

*IMPORT GDP DEFLATOR
import excel $dropbox/Data/public/FRED_GDP_Implicit_Price_Deflator.xls, ///
	firstrow clear cellrange(A11)
gen year = year(observation_date)
keep year deflator2014
rename deflator2014 gdp_deflator2014

order year gdp

save $repodir/generated_data/deflators, replace

********************************************************************************
tempsetup
capture log close
exit
