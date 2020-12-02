/* USE EIA DATA TO DETERMINE WHICH PROPOSED PLANTS ARE COMPLETED BY YEAR */
********************************************************************************
local fname proposal_analysis

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

set scheme s1color

********************************************************************************
* PREP DATA
********************************************************************************
use "$repodir/generated_data/eia860_proposed_and_operating.dta",clear
keep if has_wind == 1 // keep only wind plants
drop if eia860_proposal_year==. // plants that show up in the 860 operating data without ever showing up in the 860 proposed data
drop if eia860_proposal_year>first_yr_oper & eia860_proposal_year!=. // drop expansions to existing facilities (these data are at plant rather than generator level)
drop if proposed_year<eia860_proposal_year // data issue that only affects four plants from this subsample
bys facilityid (eia860_proposal_year): keep if _n==1 // keep earliest proposal only

********************************************************************************
* SHARE EVER COMPLETED
********************************************************************************
graph drop _all
* share completed
preserve
drop if last_eia860_proposal_year==2016 & was_built==0
collapse was_built, by(proposed_year)
lab var was_built "Share of Plants Ever Completed"
lab var proposed_year "Initial Expected Completion Year"
keep if inrange(proposed_year,2004,2014)
twoway scatter was_built proposed_year, ///
	xline(2010.5, lwidth(40) lc(gs13)) ///
	ysc(r(0 1)) ylab(0(0.2)1)
graph export "$outdir/figures/proposal_data_ever_completed.png", replace
restore

********************************************************************************
* SHARE COMPLETED NO LATER THAN ONE YEAR AFTER INTITIAL EXPECTED YEAR ONLINE
********************************************************************************
* share completed
preserve
gen on_time = first_yr_oper-proposed_year<=1
collapse on_time, by(proposed_year)
lab var on_time "Share of Plants Completed by Expected Year+1"
lab var proposed_year "Initial Expected Completion Year"
keep if inrange(proposed_year,2004,2014)
twoway scatter on_time proposed_year, ///
	xline(2010.5, lwidth(40) lc(gs13)) ///
	ysc(r(0 1)) ylab(0(0.2)1)
graph export "$outdir/figures/proposal_data_completed_on_time.png", replace
restore

********************************************************************************
tempsetup
capture log close
exit
