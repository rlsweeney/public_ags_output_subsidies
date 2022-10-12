* Pull in and clean SNL data*
clear
local fname snl_prep

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
import excel "$dropbox\Data\proprietary\snl\snl_wind_farms_static.xlsx", sheet("Static") firstrow clear
renvars, lower
drop if eiasitecode == ""

local vars_of_interest eiasitecode plantoperator plantoperatorinstitutionkey ///
                       operatorsultimateparent  operatorsultimateparentinsti regulatoryindustry ///
					   regulatorystatus owner isoname nercregioncode nercsubregioncode ///
					   largestppacounterparty largestppacontractedcapacity activepowerpurchaseagreement
keep `vars_of_interest'
rename (`vars_of_interest') ///
       (facilityid operator operatorid operator_parent operator_parentid ///
	    regulatory_industry regulatory_status owner_name iso nerc_region nerc_subregion ///
		ppa_counterparty ppa_contracted_capacity_snl active_ppa_snl) 
destring facilityid, replace

* Put SNL at the following variables that also are in EIA
renvars operator operatorid regulatory_status owner_name iso nerc_region nerc_subregion, postfix("_snl")

* For facilities that occur twice (n = 1) take the second one
bys facilityid: keep if _n == _N

save "$generated_data/snl_data.dta", replace
********************************************************************************
tempsetup
capture log close
exit

