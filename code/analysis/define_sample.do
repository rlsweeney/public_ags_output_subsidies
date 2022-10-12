/* THIS FILE TAKES CLEANED DATA, CONSTRUCTS SOME NEW VARIABLES
AND RESTRICTS THE SAMPLE */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************

use "$repodir/generated_data/final_panel_static.dta", clear

* create indicator for public ownership based on EIA's entity_type
gen public = 0
replace public = 1 if inlist(entity_type,"Federally-Owned Utility", ///
	"Municipally-Owned Utility", "Political Subdivision","State-Owned Utility", ///
	"Cooperative","Political Subdivision")

rename a1603 flag_1603
replace flag_1603 = 0 if flag_1603 == .
label var flag_1603 "1603 Grant" 

gen ott_category = "Contract"
replace ott_category = "Direct/Utility" if offtaketype=="Direct Use: Non-Utility"| offtaketype=="Direct Use: Utility-Owned" 
replace ott_category = "Merchant" if offtaketype=="Merchant"| offtaketype=="Quasi-Merchant"
replace ott_category = "" if offtaketype == "Unknown" | offtaketype == ""
egen off_cat_num = group(ott_category)

lab var powerpurchasertype "powerpurchasertype (AWEA)"
lab var offtaketype "offtaketype (AWEA)"
lab var ott_category "categorization of offtaketype (AWEA)"

*PPA INFO
**AWEA
gen tk = strpos(offtaketype,"PPA")
gen ppa_dummy_awea = cond(tk ==0,0,1)
drop tk
lab var ppa_dummy_awea "PPA (AWEA)"
replace ppa_dummy_awea = 1 if ppastartyear !=""

**SNL
gen ppa_dummy_snl = cond(active_ppa_snl == "Yes",1,0)
gen ppa_dummy = ppa_dummy_snl
replace ppa_dummy = ppa_dummy_awea if active_ppa_snl == "NA"

replace ppa_dummy =max(ppa_dummy_awea,ppa_dummy_snl)
label var ppa_dummy  "PPA"


gen ipp_dummy = cond(entity_type == "Independent Power Producer",1,0)
label var ipp_dummy  "IPP"

*USE ISO FROM SNL
gen iso_rto_code = cond(iso_snl!= "",iso_snl,isortocode)
replace iso_rto_code = "ISONE" if iso_rto_code == "New England"
replace iso_rto_code = "NYISO" if iso_rto_code == "New York"

replace iso_rto_code = isortocode if iso_rto_code == "MISO, SPP" & isortocode != ""
replace iso_rto_code = isortocode if iso_rto_code == "MISO, PJM" & isortocode != ""
replace iso_rto_code = isortocode if iso_rto_code == "ERCOT, SPP" & isortocode != ""

replace iso_rto_code = "SPP" if iso_rto_code == "MISO, SPP"
replace iso_rto_code = "PJM" if iso_rto_code == "MISO, PJM"
replace iso_rto_code = "SPP" if iso_rto_code ==  "ERCOT, SPP"
gen iso_dummy = cond(iso_rto_code =="",0,1)
lab var iso_dummy "ISO/RTO"
	
save static_indata, replace

*NEED POWER CURVE CAPACITY TO SCALE CAPACITY FACTORS
use static_indata, clear
keep facilityid powercurve_max_cap
merge 1:m facilityid using "$repodir/generated_data/final_panel_dynamic.dta", nogen 

quietly {
do $repodir/code/analysis/prep_panel_data
}

*GET FIRST AVAILABLE TURBINE SIZE AND CAPACITY INFO
foreach tv of varlist turbsize nameplate_capacity turbine_num {

	capture drop tk
	gen tk = cond(`tv' == .,1,0)
	capture drop tn
	sort facilityid tk year month
	by facilityid tk: gen tn = _n
	capture drop ts
	gen ts = `tv'  if tn == 1
	replace ts = . if tk == 1
	egen first_`tv' = mean(ts), by(facilityid)
	drop ts tk tn
}

save panel_indata, replace

*DEFINE SAMPLE AND SAVE CLEAN OUTPUT
use panel_indata, clear

*CHECK IF ANY PTNL CAPACITY FACTORS SEEM WAY OFF
gen te = capacity_factor/ ptnl_cf_adj*100 if year > 2009 & year < 2015
egen avgPtnlCFratio = mean(te), by(facilityid) 
sum avgPtnlCFratio, detail
drop te

sort facilityid ymdate
by facilityid: gen te = _n
drop if te > 1
keep facilityid first_* avgPtnlCFratio
merge 1:1 facilityid using static_indata, nogen 

*ENCODE STRING VARS WE ARE GONNA TRANSLATE INTO FES 
egen nercnum = group(nercregion) 
egen snum = group(state)
egen turbnum = group(powercurve_turbinemodel) //  i.turbnum
egen entnum = group(entity_type)
egen isonum = group(iso_rto)

*DEFINE SAMPLE 
gen insample = 1

*DROP OBSERVATIONS WITH PROBLEMATIC EIA DATA
replace insample = 0 if facilityid == 7771 /* It is missing for like 6 years then comes back online */
replace insample = 0 if facilityid == 56402 /* This one goes offline in 2008. Excluding from matches */
replace insample = 0 if facilityid == 58092 /* Shows up only in 2012 923, and it is duplicative (facilityid 7526 includes this capacity and generation) */

* RESTRICT TO CONTINENTAL US 
replace insample = 0 if state=="AK" | state=="HI"

gen _N_total = insample


*PUBLIC PLANTS NOTE ELIGBLE FOR SUBSIDY
replace insample = 0 if public == 1
gen flag_iou_ipp = (entity_type == "Independent Power Producer" | entity_type == "Investor-Owned Utility") 
replace insample = 0 if flag_iou_ipp ==0 // Drop commercial and industrial facilities

gen _N_type = insample

/*******************************************************************************
THERE ARE TWO DIFFERENT WAYS TO DEFINE ENTRY DATE: FIRST MONTH OF GENERATION IN EIA 923 DATA OR THE EIA 860 ONLINE DATE
- use EIA 860 
- exclude from sample if plants have 860 < 2009 & 923 > 2009
	-- this is most likely due to delays in reporting , but just to make sure
- plants with 923 < 860 is likely testing, but excluding just in case
*******************************************************************************/
format ope_date_min %tm
gen ope_date_ym = ym(year(ope_date_min),month(ope_date_min))
format ope_date_ym %tm
gen ope_y_min = year(ope_date_min)

gen firstyear = ope_y_min 

*THIS LINE DROPS PLANTS WHERE ELIGIBILITY FOR THE 1603 IS AMBIGUOUS, AS PRODUCTION BEGINS AFTER 2009 BUT 860 ONLINE DATE IS PRE 2009
replace insample = 0 if first_gen_year > 2008 & ope_y_min < 2009
replace insample = 0 if first_gen_year < 2009 & ope_y_min > 2008

replace insample = 0 if firstyear < 2009 & flag_1603 
replace insample = 0 if firstyear < 2002 | firstyear > 2012

*DROP 1603 PLANTS WHERE THERE IS AMBIGUITY ABOUT MATCHING TREASURY NAME TO EIA. SEE NOTES/ APPENDIX 
replace insample = 0 if flag_sample_1603 == 0 

gen _N_year = insample

gen incovars = 1
replace incovars = 0 if flag_in_awea == 0 
replace flag_in_wind = 0 if inlist(facilityid,56449,57484,56751) // THESE HAVE NONSENSICAL WIND VALUES FROM 3TIER (way too low)
replace incovars = 0 if flag_in_wind  == 0 
replace incovars = 0 if flag_powercurve < 2 // DROP PLANTS WITHOUT POWER CURVES

*create an insample flag for the eligible projects for which we were able to match to wind, contract and powercurve data
gen insample_covars = insample*incovars

*DROP PLANTS OUTSIDE OF 2 SD'S IN TERMS OF PTNL TO OBSERVED CAPACITY FACTOR (+/- 2 sd's from median) 
capture drop te
gen te = avgPtnlCFratio if insample_covars
sum te, detail
replace flag_in_wind = 0 if avgPtnlCFratio < `r(p50)' - `r(sd)'*2 | avgPtnlCFratio > `r(p50)' + `r(sd)'*2

replace insample_covars = 0 if flag_in_wind == 0

gen _N_insample_final = insample_covars

gen policy = cond(firstyear>=2009,1,0)
lab var policy "1603 Eligible"

*CREATE STATS ON SAMPLE CONSTRUCTION FOR TEXT
**HOW MANY PLANTS ARE IN EIA DATA, AND HOW MANY ARE PRIVATE, IOU-IPP 
tab _N_total _N_type
**HOW MANY ENTER 2002-2012, BY HOW MANY ARE MATCHED TO AWEA+WIND DATA
tab _N_year _N_insample_final

drop _N* 
save $repodir/generated_data/static_reg_data, replace

use panel_indata, replace
drop first_g* *power*
merge m:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match)
replace capacity_factor = capacity_factor*100

drop if year > 2014 // wind data ends 2/2015 

save $repodir/generated_data/panel_reg_data, replace

tempsetup
exit
