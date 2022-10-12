* IV REGRESSIONS
********************************************************************************
local fname rdd_regressions_negative_lmp

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

* from get_negative_price_production.do
merge 1:1 facilityid year month using "$repodir/generated_data/negative_correction.dta", nogen keep(match)

drop if iso_dummy == 0

tab iso_rto_code node_ISO_new
drop if iso_rto_code == "SPP"
drop if year == 2010

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

* define new potential cf variables, used to predict response 
drop ptnl_*
gen ptnl_cf = output_new/(monthours*turbine_capacity_pc)*100 
gen ptnl_cf_l0 = l_output_0/(monthours*turbine_capacity_pc)*100 
gen ptnl_cf_g0 = ptnl_cf - ptnl_cf_l0
gen ptnl_cf_adj = output_adj_new/(monthours*turbine_capacity_pc)*100 
gen ptnl_cf_adj_l0 = l_output_adj_0/(monthours*turbine_capacity_pc)*100 
gen ptnl_cf_adj_g0 = ptnl_cf_adj - ptnl_cf_adj_l0
	
gen ptnl_output = monthcap*ptnl_cf/100
gen ptnl_output_adj = monthcap*ptnl_cf_adj/100

save regdat, replace


* EXPORT COUNTS OF MATCHED PLANTS FOR WRITEUP 

use regdat, clear
bys facilityid: gen tn = _n
keep if tn == 1

tab flag_1603, matcell(tm)
mat list tm
local N_LMP_PTC = tm[1,1]
local N_LMP_1603 = tm[2,1]

file open myfile using "$repodir/output/estimates/N_LMP_PTC.tex", write text replace 
file write myfile "`N_LMP_PTC'"
file close myfile

file open myfile using "$repodir/output/estimates/N_LMP_1603.tex", write text replace 
file write myfile "`N_LMP_1603'"
file close myfile

keep if firstyear == 2008 | firstyear == 2009

tab flag_1603, matcell(tm)
mat list tm
local N_LMP_PTC = tm[1,1]
local N_LMP_1603 = tm[2,1]

file open myfile using "$repodir/output/estimates/N_LMP_PTC_rddsample.tex", write text replace 
file write myfile "`N_LMP_PTC'"
file close myfile

file open myfile using "$repodir/output/estimates/N_LMP_1603_rddsample.tex", write text replace 
file write myfile "`N_LMP_1603'"
file close myfile


* EXPORT SUMMARY OF NEGATIVE PRICE SHARES (HOURS AND POTENTIAL CF)
use regdat, clear

gen plant_type = cond(flag_1603 ==1,"1603","PTC")
replace share_l0 = share_l0 * 100
label var share_l0 "Share of Hours"	
label var ptnl_cf_adj_l0 "Potential Capacity Factor"
replace output_share_l0 = output_share_l0 * 100
label var output_share_l0 "Potential Output Share"

summ share_l0 if plant_type=="PTC"
local negative_hours_PTC: display %03.1f r(mean)

file open myfile using "$repodir/output/estimates/negative_hours_PTC.tex", write text replace 
file write myfile "`negative_hours_PTC'"
file close myfile

summ share_l0 if plant_type=="1603"
local negative_hours_1603: display %03.1f r(mean)

file open myfile using "$repodir/output/estimates/negative_hours_1603.tex", write text replace 
file write myfile "`negative_hours_1603'"
file close myfile

summ ptnl_cf_adj_l0 if plant_type=="PTC"
local negative_pcf_PTC: display %03.1f r(mean)

file open myfile using "$repodir/output/estimates/negative_pcf_PTC.tex", write text replace 
file write myfile "`negative_pcf_PTC'"
file close myfile

summ ptnl_cf_adj_l0 if plant_type=="1603"
local negative_pcf_1603: display %03.1f r(mean)

file open myfile using "$repodir/output/estimates/negative_pcf_1603.tex", write text replace 
file write myfile "`negative_pcf_1603'"
file close myfile

* ESTIMATE REGRESSION OF OBSERVED ON POTENTIAL CF INTERACTED WITH NEGATIVE PRICE HOURS
eststo clear

gen ind_1603_ptnl = cond(flag_1603 == 1,ptnl_cf_adj,0)
gen ind_1603_ptnl_l0 = cond(flag_1603 == 1,ptnl_cf_adj_l0,0)
gen ind_PTC_ptnl = cond(flag_1603 == 0,ptnl_cf_adj,0)
gen ind_PTC_ptnl_l0 = cond(flag_1603 == 0,ptnl_cf_adj_l0,0)

la var capacity_factor "Observed Capacity Factor"

la var ind_1603_ptnl "1603 - Potential Capacity Factor"
la var ind_1603_ptnl_l0 "1603 - Negative Price Potential Capacity Factor"

la var ind_PTC_ptnl "PTC - Potential Capacity Factor"
la var ind_PTC_ptnl_l0 "PTC - Negative Price Potential Capacity Factor"

reghdfe capacity_factor ind_PTC_ptnl ind_PTC_ptnl_l0 ind_1603_ptnl ind_1603_ptnl_l0 , ///
	absorb(facilityid date)	cluster(facilityid)

esttab, label se noconstant nonumbers star(* 0.10 ** 0.05 *** 0.01)

esttab using "$outdir/tables/negative_cf_reg_bytype.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	nonotes compress booktabs nonumber
	
* RUN PREDICTION JUST ON 1603 PLANTS 	
areg capacity_factor ptnl_cf_adj ptnl_cf_adj_l0 _Dd* if flag_1603 == 1, absorb(facilityid)

capture drop pred_cf 
predict pred_cf_base
replace ptnl_cf_adj_l0 = 0
predict pred_cf_extra
gen extra_cf = pred_cf_extra - pred_cf_base

gen capacity_factor_extra = capacity_factor
replace capacity_factor_extra = capacity_factor + extra_cf if flag_1603

save regdat_predicted, replace
 
use regdat_predicted, clear
* specify regression structure once
* restrict sample to firms that began operating between 2008-2009
keep if firstyear==2008 | firstyear==2009

gen cf_1603_adj = capacity_factor
replace  cf_1603_adj = (1 + output_share_l0_adj)*capacity_factor if flag_1603 == 1

global temp_avs _Dd* 

global covars reg_dummy ppa_dummy ipp_dummy ptnl_cf_adj windvar log_nameplate 

eststo clear

qui: eststo : ivreg2 capacity_factor (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "none", replace
		
qui: eststo : ivreg2 cf_1603_adj (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "full potential", replace				

qui: eststo : ivreg2 capacity_factor_extra (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "predicted", replace		

global temp_avs _Dd* _Dst*

qui: eststo : ivreg2 capacity_factor (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "none", replace
		estadd local state "Y", replace
		
qui: eststo : ivreg2 cf_1603_adj (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "full potential", replace				
		estadd local state "Y", replace

qui: eststo : ivreg2 capacity_factor_extra (flag_1603 = policy) $covars $temp_avs , cluster(facilityid) partial($temp_avs) first
		mat def a = e(first)
		estadd local fstat = round(a[4,1])
		estadd local model = "predicted", replace		
		estadd local state "Y", replace

esttab, keep(flag_1603)	///
	s(model state N fstat, ///
		label("Output Adjustment" "State FE" "N" "First-stage F-stat.")) ///
	se noconstant nonumbers label star(* 0.10 ** 0.05 *** 0.01)

*EXPORT FOR PAPER
esttab using "$outdir/tables/rdd_regs_negative_output.tex" , ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(flag_1603) nonotes compress order(flag_1603) ///
	s(model state N fstat, ///
		label("Output Adjustment" "State FE" "N" "First-stage F-stat.")) ///
	nomtitles booktabs 
	
	
tempsetup
cd "$repodir" 
capture log close
exit
