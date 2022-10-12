/*******************************************************************************
Compute correlations between productivity and price for Parish and McLaren discussion
********************************************************************************/
local pm_model

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/* RUN POLICY EVAL DATA PREP ***************************************************
- CLEANS DATA; 
- ASSIGNS TE FROM ESTIMATES; 
- DEFINES A PROGRAM TO COMPUTE DISCOUNTED PROFITS */

do "$repodir/code/analysis/prep_policyeval.do"

save policydata, replace

use policydata, clear 

* convert these to lcoe terms: 25 years, discount factor of 0.05
local nyears = 25
local r = 0.05
local lifemonths = `nyears'*12
local mrate = (1+`r')^(1/12)-1 // monthly equivalent of annual rate when compounded
gen df_an_T = (1 - (1 + `mrate')^(-`lifemonths'))/`mrate' 

* use capacity factor and annuity to get discounted quantity per mw over 25 years
* [730 is average number of hours in a month 8760/12]
gen dQ_mw = capacity_factor * 730 * df_an_T // d signifies "discounted" ; "delta" is change 


* define measure of investment intensity
gen qF = dQ_mw/(cost_mw*1e6) // return cost_mw to dollar terms, not millions
*gen lcoe = 1/qF
*summ lcoe

* correlate with average price 
twoway (scatter avg_p qF if flag_1603 == 1) (lfit avg_p qF if flag_1603 == 1), ///
	xtitle("Investment Productivity (PDV MWh / Investment Cost $)") /// 
	ytitle("Average Price ($/MWh)") ///	note("Vertical line denotes availability of 1603 cash grant for wind farms entering after January 1, 2009.")
	scheme(s1color) legend(off)
	
graph export "$outdir/figures/price_vs_capprod_1603.png", replace

corr qF avg_p if flag_1603 == 1
local pm_corr_1603 = round(`r(rho)',.01)
di `pm_corr_1603'

file open myfile using "$repodir/output/estimates/pm_corr_1603.tex", write text replace 
file write myfile "`pm_corr_1603'"
file close myfile

*same thing for all post 2008 plants 

* correlate with average price 
twoway (scatter avg_p qF) (lfit avg_p qF), ///
	xtitle("Investment Productivity (PDV MWh / Investment Cost $)") /// 
	ytitle("Average Price ($/MWh)") ///	note("Vertical line denotes availability of 1603 cash grant for wind farms entering after January 1, 2009.")
	scheme(s1color) legend(off)
	
graph export "$outdir/figures/price_vs_capprod_all.png", replace

corr qF avg_p 

local pm_corr_all = round(`r(rho)',.01)
di `pm_corr_all'

file open myfile using "$repodir/output/estimates/pm_corr_all.tex", write text replace 
file write myfile "`pm_corr_all'"
file close myfile

********************************************************************************
cap graph close
tempsetup
capture log close
exit
