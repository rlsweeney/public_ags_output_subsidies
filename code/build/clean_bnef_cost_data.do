/*******************************************************************************
THIS FILE IMPORTS AND CLEANS EXTERNAL PROPRIETARY DATA FROM
BNEF AND SNL, AND GOOGLED COST DATA 
********************************************************************************/
local fname clean_bnef_cost_data

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/*******************************************************************************/
*IMPORT EXTERNAL COST ESTIMATES 

* GOOGLE COST DATA
import delimited $dropbox/Data/public/USplants_Costs_GoogleSearch.csv, clear 
destring costestimate, gen(CostGoogle) force
rename costflag CostGoogle_Flag
destring plantcode, gen(facilityid) force
keep facilityid CostGoogle* facilityid 
keep if CostGoogle_Flag == .5 | CostGoogle_Flag == 1
save costs_google, replace

*IMPORT BNEF DATA 
** PLANT STACK 
import excel "$dropbox/Data/proprietary/bnef/2020-02-03 - U.S. Power Plant Stack Raw Data and User Guide.xlsx", ///
	firstrow clear cellrange(B7) sheet("Generator Data")
save indata, replace

use indata, clear
keep if tech == "Wind"
rename plantid facilityid 
rename windturbinehubheight HubHeight_bnef 
rename windnumberofturbines NumTurbines_bnef
rename windpredominantturbinemanufac TurbineFirm_bnefStack
rename windpredominantturbinemodel TurbineModel_bnefStack

keep bnefwebsiteid *_bnef* facilityid 

foreach v of varlist bnefwebsiteid HubHeight NumTurbines facilityid {
	destring `v', replace force
}

save bnef_stack, replace

** PPAs
import excel "$dropbox/Data/proprietary/bnef/2018-12-19 - U.S. Renewable PPA Prices Hit Record Lows in 2018.xlsm", ///
	firstrow clear cellrange(D10) sheet("PPA prices and contract details")
keep if tech == "Wind"
	
rename offtake_priceMWh PPAPrice
rename capacityMW PPACapacity

gen capp = PPACapacity*PPAPrice

collapse (median) PPA_bnef_median = PPAPrice (mean) PPA_bnef_mean = PPAPrice ///
		(sum) PPACapacity capp (count) nPPAs_bnef = PPAPrice (max) PPA_bnef_max = PPAPrice, ///
		by(plant_id)
		
gen PPA_bnef_wgt = capp/PPACapacity
drop capp 

rename plant_id facilityid 
save bnef_ppas, replace


** BNEF PROJECT COSTS
import excel "$dropbox/Data/proprietary/bnef/renewableProject_NorthAmericaCarribean.xlsx", ///
	firstrow clear cellrange(A14)
rename RenewableProjectID bnefwebsiteid	
rename CapacitytotalMWe Capacity_bnef
rename TotalValuem Cost_bnef 
keep if Country =="United States"

keep bnefwebsiteid Capacity_bnef Cost_bnef 
save bnef_costs, replace


use bnef_stack, clear
*KEEP BIGGEST UNIT 
gsort bnefwebsite -NumTurbines
by bnefwebsite: gen tn = _n
keep if tn ==1 
drop tn
merge 1:1 bnefwebsiteid using bnef_costs, nogen keep(match master) 

gen ccap = Capacity_bnef if Cost_bnef != . 

collapse (sum) Capacity_bnef Cost_bnef ccap /// 
	(count) nBNEFprojects = bnefwebsiteid, 	by(facilityid)

gen costbnef_permw = Cost_bnef/ccap 
drop ccap
merge 1:1 facilityid using bnef_ppas, nogen keep(match master) 
save bnef_all, replace

* SNL cost data 
import excel "$dropbox/Data/proprietary/snl/SNL_PlantData_Static_20191122_removedblankrows.xls", ///
	firstrow clear
destring EIASiteCode, force gen(facilityid)
destring OperatingCapacityMW, force gen(CapacitySNL)
destring CompletedPhasesProjectCost, force gen(CostSNL) 
rename CompletedPhasesSNLEstimatedC CostSNL_EstFlag 
destring CompletedPhasesNetCapacityCh, force gen(CostSNL_Capacity)
replace CostSNL = CostSNL/1000
gen costsnl_permw = CostSNL/CostSNL_Capacity

keep if CostSNL_EstFlag == "No"
drop if costsnl_permw < .5 | costsnl_permw > 10
drop if facilityid == . 
keep Cost* costsnl facilityid 

save snl_costs, replace

use bnef_all, clear
merge 1:1 facilityid using snl_costs, nogen
merge 1:1 facilityid using costs_google, nogen
save $repodir/generated_data/external_data_all, replace

********************************************************************************
tempsetup
capture log close
exit
