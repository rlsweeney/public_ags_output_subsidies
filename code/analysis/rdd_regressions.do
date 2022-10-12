* IV REGRESSIONS
********************************************************************************
local fname rdd_regressions

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

********************************************************************************
* PREP DATA 
********************************************************************************
use $repodir/generated_data/panel_reg_data, clear
keep if insample_covars
* restrict to balanced panel
keep if year>=2010

clonevar date = ymdate
xi i.state i.windclass_eia i.date i.nercnum i.off_cat_num ///
	i.ott i.iso_rto_code i.entnum, prefix(_D) noomit
drop  _Ddate_659 // drop same period in each reg
drop if age == 0 // output could be for partial month at time 0
replace log_netgen = log(netgen + 1)
gen log_ptnl_output_adj = log(ptnl_output_adj)
lab var log_ptnl_output_adj "log(Potential Output)"
lab var ptnl_cf_adj "Potential Capacity Factor"
lab var design_windspeed_eia "Design Wind Speed"

save regdat_bw, replace

* restrict sample to firms that began operating between 2008-2009
keep if firstyear==2008 | firstyear==2009

save regdat, replace

use regdat, clear
* specify regression structure once

global avs _Dd*

global covars reg_dummy ppa_dummy ipp_dummy ptnl_cf_adj windvar log_nameplate 

capture program drop estimateregs
program define estimateregs
	eststo clear
	*	ols regressions	
	eststo: reg $dv flag_1603 $avs , robust cluster(facilityid)
		estadd local regtype "OLS", replace
		estadd local state "N", replace
		estadd local covars "N", replace
		local r2a : di %9.3f e(r2_a)
		estadd local r2a `r2a'
	eststo tk1: reg $dv flag_1603 $avs $covars , cluster(facilityid)
		estadd local regtype "OLS", replace
		estadd local state "N", replace
		estadd local covars "Y", replace
		local r2a : di %9.3f e(r2_a)
		estadd local r2a `r2a'
	eststo tk2: reg $dv flag_1603 $avs $covars _Dst* , cluster(facilityid)
		estadd local regtype "OLS", replace
		estadd local state "Y", replace
		estadd local covars "Y", replace
		local r2a : di %9.3f e(r2_a)
		estadd local r2a `r2a'
	*	iv regressions	
	eststo: ivreg2 $dv (flag_1603 = policy) $avs , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "N", replace
		estadd local r2a = "-", replace
	eststo tk3: ivreg2 $dv (flag_1603 = policy) $avs $covars , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "Y", replace
		estadd local r2a = "-", replace
	eststo tk4: ivreg2 $dv (flag_1603 = policy) $avs $covars _Dst* , cluster(facilityid) partial($avs _Dst*) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "Y", replace
		estadd local covars "Y", replace
		estadd local r2a = "-", replace
end

*******************
*CAPACITY FACTOR

* use potential capacity factor
global dv capacity_factor 
quietly: estimateregs
esttab, drop(_D*)	///
	s(regtype covars state r2a N fstat, ///
		label("Regression Type" "Controls" "State FE" "R-sq." "N" "First-stage F-stat.")) ///
	se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01)

*EXPORT FOR PAPER
esttab using "$outdir/tables/rdd_regressions_cf.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	drop(_D* _*) nonotes compress order(flag_1603) ///
	s(regtype covars state r2a N fstat, ///
		label("Regression Type" "Controls" "State FE" "R-sq." "N" "First-stage F-stat.")) ///
	nomtitles booktabs 
	
*EXPORT SUBSET FOR PRESENTATION
esttab tk* using "$outdir/tables/rdd_regressions_cf_prez.tex" , ///
	se noconstant nomtitles label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(flag* _cons) nonotes compress booktabs order(flag_1603) b(a2) ///
	s(regtype covars state r2a N fstat, ///
		label("Regression Type" "Controls" "State FE" "R-sq." "N" "First-stage F-stat.")) 

*SAVE PREFERRED SPEC FOR POLICY EVAL FILE
estimates clear
ivreg2 $dv (flag_1603 = policy) $avs $covars , cluster(facilityid) partial($avs ) first
estimates save "$outdir/estimates/rd_main_spec", replace


********************************************************************************
*DO SAME THING WITH LOG(NETGEN)
********************************************************************************
use regdat, clear
clonevar tlog_nameplate = log_nameplate // gets dropped in esttab with program above
global dv log_netgen tlog_nameplate
qui: estimateregs

esttab, drop(_D* log_nameplate)   order(flag_1603)	///
	s(regtype covars state N fstat, ///
		label("Regression Type" "Controls" "State FE" "N" "First-stage F-stat.")) ///
	se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01)

*EXPORT FOR PAPER
esttab using "$outdir/tables/rdd_regressions_gen.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	drop(_D* _*)  nonotes compress   order(flag_1603) ///
	s(regtype covars state N fstat, ///
		label("Regression Type" "Controls" "State FE" "N" "First-stage F-stat.")) ///
	nomtitles booktabs 

*EXPORT SUBSET FOR PRESENTATION
esttab tk* using "$outdir/tables/rdd_regressions_gen_prez.tex" , ///
	se noconstant nomtitles label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(flag* _cons)  nonotes compress booktabs  order(flag_1603) b(a2) ///
	s(regtype covars state N fstat, ///
		label("Regression Type" "Controls" "State FE" "N" "First-stage F-stat.")) 

********************************************************************************
/* ROBUSTNESS: INCLUDE PIECEWISE LINEAR TREND */
********************************************************************************
use regdat, clear

* add distance from policy elegibility change for IV/RD
gen dist = ope_date_ym - ym(2009,1)

lab var dist "Distance"
gen firstmonth = month(ope_date_ym)
* use potential capacity factor
global dv capacity_factor
*global dv log_netgen log_nameplate 
gen dist_post = cond(policy == 1, dist,0)
lab var dist_post "Distance x Post"
global ltvars dist dist_post 
qui{
	eststo clear
	*	iv regressions	
	eststo: ivreg2 $dv (flag_1603 = policy) $avs , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "N", replace
		estadd local trend "N", replace
	eststo tk1: ivreg2 $dv (flag_1603 = policy) $avs $covars , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "Y", replace
		estadd local trend "N", replace
	eststo tk2: ivreg2 $dv (flag_1603 = policy) $avs $covars _Dst* , cluster(facilityid) partial($avs _Dst*) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "Y", replace
		estadd local covars "Y", replace
		estadd local trend "N", replace
	*	iv regressions	
	eststo: ivreg2 $dv (flag_1603 = policy) $avs $ltvars , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "N", replace
		estadd local trend "Y", replace
	eststo tk3: ivreg2 $dv (flag_1603 = policy) $avs $covars  $ltvars , cluster(facilityid) partial($avs ) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "N", replace
		estadd local covars "Y", replace
		estadd local trend "Y", replace
	eststo tk4: ivreg2 $dv (flag_1603 = policy) $avs $covars _Dst*  $ltvars , cluster(facilityid) partial($avs _Dst*) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local regtype "2SLS", replace
		estadd local state "Y", replace
		estadd local covars "Y", replace
		estadd local trend "Y", replace
}

esttab , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	drop(*dist*) nonotes compress order(flag_1603) ///
	s(regtype covars state trend N fstat, ///
		label("Regression Type" "Controls" "State FE" "Trend" "N" "First-stage F-stat.")) ///
	nomtitles 
	
*EXPORT FOR PAPER
esttab using "$outdir/tables/rdd_regressions_cf_linear.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	drop(*dist*) nonotes compress order(flag_1603) ///
	s(regtype covars state trend N fstat, ///
		label("Regression Type" "Controls" "State FE" "Piecewise Trend" "N" "First-stage F-stat.")) ///
		nomtitles booktabs 

*EXPORT SUBSET FOR PRESENTATION
esttab tk* using "$outdir/tables/rdd_regressions_cf_linear_prez.tex" , ///
	se noconstant nomtitles label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(flag* *dist*) nonotes compress booktabs order(flag_1603) b(a2) ///
	s(regtype covars state trend N fstat, ///
		label("Regression Type" "Controls" "State FE" "Trend" "N" "First-stage F-stat.")) 
		
********************************************************************************
/* ROBUSTNESS: GENERATE PLOTS AND REGRESSION TABLES FOR ALTERNATIVE BANDWIDTHS */
********************************************************************************
* this code requires the user-written package coefplot
// ssc install coefplot
********************************************************************************
set scheme s1color
use regdat_bw, clear
capture drop firstdate
clonevar firstdate = ope_date_ym

global bw_covars reg_dummy ppa_dummy ipp_dummy windvar log_nameplate

foreach var in log_netgen capacity_factor {
	foreach spec in nostateFEs stateFEs {
		est clear
		eststo clear
		if `var'==log_netgen {
			global dv log_netgen log_nameplate log_ptnl_output_adj
			}
		else if `var'==capacity_factor {
			global dv capacity_factor ptnl_cf_adj
			}
		foreach i in 3 6 9 12 15 18 21 24 {
			if "`spec'"=="nostateFEs" {
				eststo: quietly ivreg2 $dv (flag_1603 = policy) $avs $bw_covars        if firstdate>=ym(2009,1)-`i' & firstdate<=ym(2009,1)+`i'-1, cluster(facilityid) partial($avs )
			}
			else if "`spec'"=="stateFEs" {
				eststo: quietly ivreg2 $dv (flag_1603 = policy) $avs $bw_covars _Dst*  if firstdate>=ym(2009,1)-`i' & firstdate<=ym(2009,1)+`i'-1, cluster(facilityid) partial($avs _Dst* )
			}
			estimates store m`i'
		}
		if `var'==log_netgen {
			coefplot ///
				m3, bylabel(3) || m6, bylabel(6) || m9, bylabel(9) || m12, bylabel(12) || ///
				m15, bylabel(15) || m18, bylabel(18) || m21, bylabel(21) || m24, bylabel(24) ///
				bycoefs keep(flag_1603) vertical yline(0) ///
				coeflabels(flag_1603 = " ") ///
				xtitle("Bandwidth (Months)") ///
				ytitle("1603 Grant Coefficient Estimate")
			graph export "$outdir/figures/fuzzyRDD_loggen_bandwidths_`spec'.png", replace
			
			esttab using "$outdir/tables/fuzzyRDD_loggen_bandwidths_`spec'.tex", ///
				se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01) replace  ///
				keep(flag_1603) mtitles("3 mo." "6 mo." "9 mo." "12 mo." "15 mo." "18 mo." "21 mo." "24 mo.") ///
				s(N widstat, label("N" "First-stage F-stat.")) ///
				title("Robustness: Sensitivity of Grant Impact to Bandwidth\label{RDD:loggenbandwidth}") ///
				substitute("Standard errors in parentheses" "Standard errors clustered by facility in parentheses.")
		}
		else if `var'==capacity_factor {
			coefplot ///
				m3, bylabel(3) || m6, bylabel(6) || m9, bylabel(9) || m12, bylabel(12) || ///
				m15, bylabel(15) || m18, bylabel(18) || m21, bylabel(21) || m24, bylabel(24) ///
				bycoefs keep(flag_1603) vertical yline(0) ///
				coeflabels(flag_1603 = " ") ///
				xtitle("Bandwidth (Months)") ///
				ytitle("1603 Grant Coefficient Estimate")
			graph export "$outdir/figures/fuzzyRDD_capfactor_bandwidths_`spec'.png", replace
			
			esttab using "$outdir/tables/fuzzyRDD_capfactor_bandwidths_`spec'.tex", ///
				se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01) replace  ///
				keep(flag_1603) mtitles("3 mo." "6 mo." "9 mo." "12 mo." "15 mo." "18 mo." "21 mo." "24 mo.") ///
				s(N widstat, label("N" "First-stage F-stat.")) ///
				title("Robustness: Sensitivity of Grant Impact to Bandwidth\label{RDD:logCFbandwidth}") ///
				substitute("Standard errors in parentheses" "Standard errors clustered by facility in parentheses.")
		}
	}
}
********************************************************************************
cap graph close
tempsetup
cd "$repodir" 
capture log close
exit
