* SEE IF POTENTIAL CAPACITY FACTOR IMPROVES FIT
********************************************************************************
local fname wind_variable_selection

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

use $repodir/generated_data/panel_reg_data, clear
keep if insample
keep if insample_cov
keep if firstyear < 2013 & firstyear > 2004

clonevar date = ymdate
* RESTRICT TO BALANCED PANEL
keep if year>=2013

xi i.state i.windclass_eia i.date i.nercnum i.year i.month i.off_cat_num i.ott i.iso_rto_code, prefix(_D) noomit

drop if age == 0
lab var ptnl_cf_adj "Potential Capacity Factor"
lab var design_windspeed_eia "Design Wind Speed"

eststo clear
qui{
global xvar design_windspeed_eia
capture drop tg
egen tg = group(firstyear) // don't have facility fe's bc they aren't in the regressions
xi i.tg, prefix(_I) noomit
global fes _Dd* _I* 
eststo: reg capacity_factor $xvar $fes, cluster(facilityid)
eststo: reg capacity_factor $xvar wind_speed*  $fes, cluster(facilityid)
eststo: reg capacity_factor $xvar wind_speed* windvar  $fes, cluster(facilityid)
eststo: reg capacity_factor $xvar ptnl_cf_adj  $fes, cluster(facilityid)
eststo: reg capacity_factor ptnl_cf_adj  windvar  $fes, cluster(facilityid)
}

esttab, drop(_Dd* _I*) ar2	///
	s(r2_a N, label("Adjusted R-sq." "Observations")) ///
	se label star(* 0.10 ** 0.05 *** 0.01) nomtitles

*EXPORT FOR PAPER
esttab using "$repodir/output/tables/wind_covar_justification.tex" , replace ///
	drop(_*) ar2 nonotes compress ///
	s(r2_a N, label("Adjusted R-sq." "N")) ///
	se label star(* 0.10 ** 0.05 *** 0.01) ///
	nomtitles booktabs 

********************************************************************************
tempsetup
capture log close
exit
