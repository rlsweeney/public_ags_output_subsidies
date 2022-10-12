* MATCHED DIFFERENCING ESTIMATES
********************************************************************************
local fname matching

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/********************************************************************************
* PREP DATA 
- GET FACILITY LEVEL INFO TO MATCH ON
- SINCE WE ARE GOING TO BE DIFFERENCING ON JUST THE POST PERIOD, 
RESTRICT PRE-PERIOD ENTRANTS TO POST PERIOD N
*********************************************************************************/

set seed 12345
use $repodir/generated_data/panel_reg_data, clear
clonevar date = ymdate
rename log_nameplate log_cap
keep if firstyear > 2004

*RESTRICT TO YEARS WITH BOTH TYPES
drop if year < 2009 // 2013 FOR BALANCED PANEL
save indata, replace


use indata, clear
drop if year < 2013 // restrict to same years for accurate comparison of earlier plants
local meanvars ptnl_cf_adj wind_speed* nameplate turbsize capacity_factor log_cap windvar
collapse (mean) `meanvars' (min) min_reg_dummy = reg_dummy ///
	(lastnm) ppa_dummy entnum windclass_eia, by(facilityid)
merge 1:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match) 

foreach v of varlist `meanvars' {
	rename `v' avg_`v'
}

xi i.entnum, prefix(_D) noomit
	
keep if insample 
keep if insample_covars
gen turbinesize = powercurve_max_cap/1000
save cemdat, replace

***GET PANEL DATA TO MERGE TO
use indata, clear
drop if age < 12 // drop first year of production
xi i.firstyear i.state  i.windclass_eia i.date i.nercnum i.year i.month i.off_cat_num ///
	i.ott i.iso_rto_code i.entnum i.turbnum , prefix(_D) noomit
save regdat, replace

********************************************************************************
*CEM SETUP
********************************************************************************
*SET VARS THAT WILL BE MATCHED IN ALL SPECS REGARDLESS OF REGION
*preferred
local capvar avg_nameplate (10)
local windvars design_windspeed_eia windclass_eia (#0)
global match_vars min_reg_dummy (#0) entnum (#0) `capvar' `windvars' 

*SET COVARS IN EVERY REGRESSION 
global did_vars _Df* _Ddat* 

*SET ADDITIONAL COVARS TO DIFFERENCE EACH PERIOD IN SPEC WITH COVARS
global reg_covars reg_dummy ppa_dummy ipp_dummy ptnl_cf_adj windvar log_cap

global kflag // k2k restricts to 1-1 match (drops randomly though)
global wlab 1 

********************************************************************************
* PROGRAMS
********************************************************************************
*GET CEM MATCHES AND CREATE REGRESSION DATA
capture program drop run_cem
program define run_cem

	cem $cemspec, treatment(policy) $kflag
	keep facilityid cem_* policy  flag_1603
	save mdat, replace
	tab cem_match policy

	use mdat, clear
	keep if cem_match == 1
	merge 1:m facilityid using regdat, keep(match) nogen

	replace cem_weights = $wlab
	capture drop tg
end

capture program drop getNobs
program define getNobs

	use mdat, clear
	keep if cem_match == 1
	tab policy flag_1603, matcell(x)
	mat list x
	local Npre = x[1,1]
	local Nptc = x[2,1]
	local N1603 = x[2,2]


	estadd local Npre `Npre', replace
	estadd local Nptc `Nptc', replace
	estadd local N1603 `N1603', replace
end


********************************************************************************
* RUN MANY SPECIFICATION WITH A SINGLE REGION DEFINITION
********************************************************************************
eststo clear 

qui{
use cemdat, clear
keep facilityid  min_* avg_*  
merge 1:m facilityid using regdat, nogen keep(match) 

*RUN ON ALL PLANTS
qui: eststo m1 : reg capacity_factor $did_vars $reg_covars flag_1603 _Dst* , cluster(facilityid)
estadd local rsamp "All", replace
estadd local FEs "State", replace

global cemspec $match_vars snum (#0)
use cemdat, clear
run_cem

*OLS WITHOUT UNMATCHED PLANTS
qui: eststo m2 : reg capacity_factor $did_vars $reg_covars flag_1603 _Dst* , cluster(facilityid)
estadd local rsamp "Matched", replace
estadd local FEs "State", replace

*INCLUDE STRATA FES
qui: eststo m3 : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(cem_strata)
estadd local rsamp "Matched", replace
estadd local FEs "Group", replace

*INCLUDE STRATA-YEAR FES
capture drop tg
egen  tg = group(cem_strata year) 
qui: eststo m4 : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(tg)
estadd local rsamp "Matched", replace
estadd local FEs "Group*Y", replace
estimates save "$outdir/estimates/match_main_spec", replace // SAVE FOR USE IN POLICY EVAL

*INCLUDE STRATA-YEAR-MONTH FES
capture drop tg
egen  tg = group(cem_strata ymdate) 
qui: eststo m6 : areg capacity_factor  $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(tg)
estadd local rsamp "Matched", replace
estadd local FEs "Group*Y*M", replace
}
esttab , keep(*1603)	///
	s(rsamp FEs r2_a N, ///
		label("Sample" "FEs" "R-sq." "N")) ///
	nomtitles se noconstant label star(* 0.10 ** 0.05 *** 0.01)

esttab using "$outdir/tables/exact_match_state.tex", ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(*1603) ///
	s(rsamp FEs r2_a N, ///
		label("Sample" "FEs" "R-sq." "N")) ///
	nomtitles booktabs nonotes
	
esttab m1 m2 m3 m4 m6 using "$outdir/tables/exact_match_state_prez.tex", ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(*1603) ///
	s(rsamp FEs r2_a N, ///
		label("Sample" "FEs" "Controls" "R-sq." "N")) ///
	nomtitles booktabs nonotes

********************************************************************************
* RUN WITH GROUP FE'S FOR MANY SPECS
********************************************************************************

eststo clear 
global tgroups cem_strata year
qui{
*MATCH ON NERC-ISO DUMMY
global cemspec $match_vars nercnum (#0) iso_dummy 
use cemdat, clear
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
	estadd local region "Nerc-1(ISO)", replace
getNobs 

*MATCH ON ISO IF NON MISSING
global cemspec $match_vars isonum (#0)
use cemdat, clear
drop if iso_rto_code == "None" | iso_rto_code == "OTHER" |  iso_rto_code == ""
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
	estadd local region "ISO", replace
getNobs 

*MATCH ON NERC AND ISO IF NON MISSING
global cemspec $match_vars nercnum (#0) isonum (#0)
use cemdat, clear
drop if iso_rto_code == "None" | iso_rto_code == "OTHER" |  iso_rto_code == ""
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
		estadd local region "Nerc*ISO", replace
getNobs

*MATCH ON STATE
global cemspec $match_vars snum (#0) 
use cemdat, clear
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
		estadd local region "State", replace
getNobs
}

esttab , keep(*1603)	///
	s(Npre Nptc N1603 region r2_a N, ///
		label("\# Pre-PTC" "\# Post-PTC" "\# Post-1603" "Region" "R-sq." "N")) ///
	se noconstant nomtitles label star(* 0.10 ** 0.05 *** 0.01)

di "$did_vars"
di "$reg_covars"	

esttab using "$outdir/tables/exact_match_wide_table.tex", ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(*1603) ///
	s(Npre Nptc N1603 region r2_a N, ///
		label("\# Pre-PTC" "\# Post-PTC" "\# Post-1603" "Region" "R-sq." "N")) ///
	nomtitles booktabs nonotes

********************************************************************************
*SHOW BALANCE
********************************************************************************

quietly{

global cemspec $match_vars snum (#0) , treatment(policy) $kflag
use cemdat, clear
cem $cemspec
gen tnameplate = avg_log_cap
save mdat, replace


use mdat, clear
	keep if cem_match==1
	gen tgroup = cond(policy==1,1,0)
	bysort tgroup: gen periodnum = _N
	
	capture drop te
	gen te = cond(policy == 0,1,0)
	sum te 
	local Npre = r(sum)
	replace te = cond(policy == 1,1,0)
	sum te 
	local Npost = r(sum)
	replace te = cond(policy == 1 & flag_1603 == 1,1,0)
	sum te 
	local N1603 = r(sum)

global vlist avg_nameplate turbinesize design_windspeed min_reg_dummy ipp_dummy ppa_dummy avg_ptnl_cf_adj avg_capacity_factor
global rnames "Nameplate Capacity (MW)" "Turbine Size (MW)" "Design Wind Speed (MPH)" "Regulated" "IPP"  "PPA" "Potential Capacity Factor" "Capacity Factor"

local I : list sizeof global(vlist)
local ms = `I' + 2
mat T = J(`ms',4,.)

local i = 0
foreach v of varlist $vlist {
	di "`v'"
	local i = `i' + 1
	
	reg `v' tgroup [aweight = cem_weights]
	matrix tm = r(table)
	local del = tm[1,1] // estimate
	if(abs(`del') < 1e-12) local del = 0 // change -0.00 to 0.00 (numerical precision issue)
	local pdel = tm[4,1] // pvalue

	*if running on stata 16, the behavior of mean over labels changed. this should fix:
	*https://www.statalist.org/forums/forum/general-stata-discussion/general/1522859-issue-with-mean-x-over-y-command-in-stata-16
	version 15: mean `v' [aweight = cem_weights],  over(tgroup)
	mat T[`i',1] = _b[0]
	mat T[`i',2] = _b[1]
	mat T[`i',3] = `del'
	mat T[`i',4] = `pdel'
}
mat T[`i'+1,1] = `Npre' 
mat T[`i'+1,2] = `Npost' 
mat T[`i'+2,2] = `N1603' 

mat rownames T = "$rnames" "Wind Farms" "1603 Recipients"

}
frmttable using "$outdir/tables/matching_balance.tex", statmat(T) varlabels replace ///
	ctitle("", Pre, Post, Difference, "p-value") hlines(11{0}101) spacebef(1{0}10) frag tex ///
	sdec(2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 0,0,0,0 \ 0,0,0,0) 


********************************************************************************
* ROBUSTNESS TO USE OF POTENTIAL CF INSTEAD OF WIND CLASS AND DESIGN WIND SPEED
********************************************************************************
*SET VARS THAT WILL BE MATCHED IN ALL SPECS REGARDLESS OF REGION
*robustness using potential cf
local capvar avg_nameplate (10)
local windvars avg_ptnl_cf_adj
global match_vars min_reg_dummy (#0) entnum (#0) `capvar' `windvars' 

********************************************************************************
* RUN MANY SPECIFICATION WITH A SINGLE REGION DEFINITION
********************************************************************************
eststo clear 

qui{
use cemdat, clear
keep facilityid  min_* avg_*  
merge 1:m facilityid using regdat, nogen keep(match) 

*RUN ON ALL PLANTS
qui: eststo m1 : reg capacity_factor $did_vars $reg_covars flag_1603 _Dst* , cluster(facilityid)
estadd local rsamp "All", replace
estadd local FEs "State", replace

global cemspec $match_vars snum (#0)
use cemdat, clear
run_cem

*OLS WITHOUT UNMATCHED PLANTS
qui: eststo m2 : reg capacity_factor $did_vars $reg_covars flag_1603 _Dst* , cluster(facilityid)
estadd local rsamp "Matched", replace
estadd local FEs "State", replace

*INCLUDE STRATA FES
qui: eststo m3 : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(cem_strata)
estadd local rsamp "Matched", replace
estadd local FEs "Group", replace

*INCLUDE STRATA-YEAR FES
capture drop tg
egen  tg = group(cem_strata year) 
qui: eststo m4 : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(tg)
estadd local rsamp "Matched", replace
estadd local FEs "Group*Y", replace

*INCLUDE STRATA-YEAR-MONTH FES
capture drop tg
egen  tg = group(cem_strata ymdate) 
qui: eststo m6 : areg capacity_factor  $did_vars $reg_covars flag_1603 [aweight=cem_weights], cluster(facilityid) abs(tg)
estadd local rsamp "Matched", replace
estadd local FEs "Group*Y*M", replace
}
esttab , keep(*1603)	///
	s(rsamp FEs r2_a N, ///
		label("Sample" "FEs" "R-sq." "N")) ///
	nomtitles se noconstant label star(* 0.10 ** 0.05 *** 0.01)

esttab using "$outdir/tables/exact_match_state_ptnlcf.tex", ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(*1603) ///
	s(rsamp FEs r2_a N, ///
		label("Sample" "FEs" "R-sq." "N")) ///
	nomtitles booktabs nonotes
	
********************************************************************************
* RUN WITH GROUP FE'S FOR MANY SPECS
********************************************************************************

eststo clear 
global tgroups cem_strata year
qui{
*MATCH ON NERC-ISO DUMMY
global cemspec $match_vars nercnum (#0) iso_dummy 
use cemdat, clear
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
	estadd local region "Nerc-1(ISO)", replace
getNobs 

*MATCH ON ISO IF NON MISSING
global cemspec $match_vars isonum (#0)
use cemdat, clear
drop if iso_rto_code == "None" | iso_rto_code == "OTHER" |  iso_rto_code == ""
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
	estadd local region "ISO", replace
getNobs 

*MATCH ON NERC AND ISO IF NON MISSING
global cemspec $match_vars nercnum (#0) isonum (#0)
use cemdat, clear
drop if iso_rto_code == "None" | iso_rto_code == "OTHER" |  iso_rto_code == ""
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars _Dst* flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
		estadd local region "Nerc*ISO", replace
getNobs

*MATCH ON STATE
global cemspec $match_vars snum (#0) 
use cemdat, clear
run_cem
egen  tg = group($tgroups) 
eststo : areg capacity_factor $did_vars $reg_covars flag_1603 [aweight=cem_weights], /// 
			cluster(facilityid) abs(tg)
		estadd local region "State", replace
getNobs
}

esttab , keep(*1603)	///
	s(Npre Nptc N1603 region r2_a N, ///
		label("\# Pre-PTC" "\# Post-PTC" "\# Post-1603" "Region" "R-sq." "N")) ///
	se noconstant nomtitles label star(* 0.10 ** 0.05 *** 0.01)

di "$did_vars"
di "$reg_covars"	

esttab using "$outdir/tables/exact_match_wide_table_ptnlcf.tex", ///
	se noconstant label star(* 0.10 ** 0.05 *** 0.01) replace  ///
	keep(*1603) ///
	s(Npre Nptc N1603 region r2_a N, ///
		label("\# Pre-PTC" "\# Post-PTC" "\# Post-1603" "Region" "R-sq." "N")) ///
	nomtitles booktabs nonotes
********************************************************************************
tempsetup
cd "$repodir" 
capture log close
exit
