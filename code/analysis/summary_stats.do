* SUMMARY STATISTICS
********************************************************************************
local fname summary_stats

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup
* this code uses tabout
//ssc install tabout

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/* COMPARISON OF PROJECT CHARACTERISTICS */

use $repodir/generated_data/panel_reg_data, clear

keep if year > 2012 // restrict so wind vars etc are same period 
collapse (mean) ptnl_* wind* reg_dummy capacity_factor , by(facilityid)
merge 1:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match)
keep if insample
keep if insample_covars
gen turbinesize = powercurve_max_cap/1000
save crossdata, replace 


global vlist first_nameplate turbinesize design_windspeed reg_dummy ipp_dummy ppa_dummy ptnl_cf_adj capacity_factor subsidynum
global rnames "Nameplate Capacity (MW)" "Turbine Size (MW)" "Design Wind Speed (MPH)" "Regulated" "IPP"  "PPA" "Potential Capacity Factor" "Capacity Factor" "New Wind Farms"
*COMPARE PTC VS 1603
quietly{
use crossdata, clear

keep if firstyear > 2008 & firstyear < 2013 
gen tgroup = flag_1603
bysort tgroup: gen subsidynum = _N

local I : list sizeof global(vlist)
mat T = J(`I',4,.)

local i = 0
foreach v of varlist $vlist {
	local i = `i' + 1
	ttest `v', by(tgroup)
	mat T[`i',1] = r(mu_1)
	mat T[`i',2] = r(mu_2)
	mat T[`i',3] = r(mu_1) - r(mu_2)
	mat T[`i',4] = r(p)
	
}
mat T[`i',3] = . // eliminate difference for # observations
mat T[`i',4] = . // eliminate difference for # observations

mat rownames T = "$rnames"
}
frmttable using "$outdir/tables/ttest_PTCvs1603.tex", statmat(T) varlabels replace ///
	ctitle("", PTC, 1603, Difference, "p-value") hlines(11{0}11) spacebef(1{0}1) frag tex ///
	sdec(2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2  \ 0,0,0,0)

*COMPARE PTC VS 1603 IN 2009 ONLY
quietly{
use crossdata, clear
keep if firstyear == 2009
gen tgroup = flag_1603
bysort tgroup: gen subsidynum = _N

drop tgroup subsidynum
gen tgroup = flag_1603
bysort tgroup: gen subsidynum = _N
	
local I : list sizeof global(vlist)
mat T = J(`I',4,.)

local i = 0
foreach v of varlist $vlist {
	local i = `i' + 1
	ttest `v', by(tgroup)
	mat T[`i',1] = r(mu_1)
	mat T[`i',2] = r(mu_2)
	mat T[`i',3] = r(mu_1) - r(mu_2)
	mat T[`i',4] = r(p)
	
}
mat T[`i',3] = . // eliminate difference for # observations
mat T[`i',4] = . // eliminate difference for # observations

mat rownames T = "$rnames"
}
frmttable using "$outdir/tables/ttest_PTCvs1603_2009.tex", statmat(T) varlabels replace ///
	ctitle("", PTC, 1603, Difference, "p-value") hlines(11{0}11) spacebef(1{0}1) frag tex ///
	sdec(2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2  \ 0,0,0,0)

*COMPARE PTC VS 1603 IN 2012 ONLY
quietly{
use crossdata, clear
keep if firstyear == 2012
gen tgroup = flag_1603
bysort tgroup: gen subsidynum = _N
	
local I : list sizeof global(vlist)
mat T = J(`I',4,.)

local i = 0
foreach v of varlist $vlist {
	local i = `i' + 1
	ttest `v', by(tgroup)
	mat T[`i',1] = r(mu_1)
	mat T[`i',2] = r(mu_2)
	mat T[`i',3] = r(mu_1) - r(mu_2)
	mat T[`i',4] = r(p)
	
}
mat T[`i',3] = . // eliminate difference for # observations
mat T[`i',4] = . // eliminate difference for # observations

mat rownames T = "$rnames"
}
frmttable using "$outdir/tables/ttest_PTCvs1603_2012.tex", statmat(T) varlabels replace ///
	ctitle("", PTC, 1603, Difference, "p-value") hlines(11{0}11) spacebef(1{0}1) frag tex ///
	sdec(2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2  \ 0,0,0,0)

******************************************************************
*COMPARE 2008 VS 2009
quietly {
use crossdata, clear
	keep if firstyear==2009 | firstyear == 2008
	gen tgroup = cond(firstyear==2009,1,0)
	bysort tgroup: gen periodnum = _N
	
	bysort flag_1603: gen temp = _N
	replace temp = 0 if flag_1603==0
	egen subsidynum = max(temp) if firstyear==2009
	replace subsidynum = 0 if subsidynum==.
	drop temp

global vlist first_nameplate turbinesize design_windspeed reg_dummy ipp_dummy ppa_dummy ptnl_cf_adj capacity_factor periodnum subsidynum 
global rnames "Nameplate Capacity (MW)" "Turbine Size (MW)" "Design Wind Speed (MPH)" "Regulated" "IPP" "PPA" "Potential Capacity Factor" "Capacity Factor" "New Wind Farms" "1603 Recipients" 

local I : list sizeof global(vlist)
mat T = J(`I',4,.)

local i = 0
foreach v of varlist $vlist {
	local i = `i' + 1
	ttest `v', by(tgroup)
	mat T[`i',1] = r(mu_1)
	mat T[`i',2] = r(mu_2)
	mat T[`i',3] = r(mu_1) - r(mu_2)
	mat T[`i',4] = r(p)
}
mat T[`i'-1,3] = . // eliminate difference for # observations
mat T[`i',3] = . // eliminate difference for # observations
mat T[`i',4] = . // eliminate difference for # observations

mat rownames T = "$rnames "
}

frmttable using "$outdir/tables/ttest_2008vs2009.tex", statmat(T) varlabels replace ///
	ctitle("", 2008, 2009, Difference, "p-value") hlines(11{0}101) spacebef(1{0}10) frag tex ///
	sdec(2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 2,2,2,2 \ 0,0,0,0 \ 0,0,0,0) 

******************************************************************
*SHARE OF 2008-2009 PLANTS USING THE SAME TURBINES
use crossdata, clear
keep if firstyear==2008 | firstyear==2009
bys turbnum: egen minyear = min(firstyear)
bys turbnum: egen maxyear = max(firstyear)
count if minyear!=maxyear
gen minmax = 0
replace minmax = 1 if minyear!=maxyear
summarize minmax, meanonly
local stat = round(`r(mean)'*100)
file open myfile using "$repodir/output/estimates/stat_pct_same_turbines.tex", write text replace 
file write myfile "`stat'"
file close myfile

********************************************************************************  nocenter
*CREATE SUMMARY STATS TABLE FOR ALL YEARS TO SHOW TRENDS
use $repodir/generated_data/panel_reg_data, clear
keep if inrange(firstyear,2002,2014)
keep if year == 2014

collapse (mean) ptnl_* wind* reg_dummy capacity_factor, by(facilityid)
merge 1:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match)

replace flag_1603 = 0 if firstyear < 2009 // *ADDED FOOTNOTE IN TEXT THESE ARE EXCLUDED (insample==0)
*Export Table to Latex
gen N = 1
tabout firstyear using "$outdir/tables/annual_sum_stats.tex", replace ///
c(sum N sum insample_covars sum flag_1603 ///
	mean flag_iou_ipp mean reg_dummy /// 
	mean first_nameplate mean first_turbsize mean design_windspeed mean capacity_factor) sum ///
f(0c 0c 0c 2.2c) ///
style(tex) bt ///
topf($repodir/code/analysis/top.tex) topstr(\textwidth) ptotal(none) total(none) botf($repodir/code/analysis/bot.tex) ///
h1(nil) ///
h2(nil) ///
h3(Year & Plants (all) & Plants (sample) & Plants (1603) & IOU or IPP & Regulated & Capacity & Turbine Size & Wind Speed & Capacity Factor \\ ) wide(5)

********************************************************************************
*PLOT OF ENTRANTS OVER TIME

use $repodir/generated_data/static_reg_data, clear
*gen firstdate = first_gen_date 
gen firstdate = ym(year(ope_date_min),month(ope_date_min))

// GENERATE ENTRY PLOT USING EIA 923 DATA IN STYLE OF RD PLOTS
bys firstdate: egen number = count(facilityid)
twoway bar number firstdate if firstdate>=ym(2002,1) & firstdate<=ym(2012,12), ///
	tline(2009m1)  ///
	xtitle("Month Placed in Service") ytitle("New Wind Farms") xlabel(504(24)636 , format(%tm_CCYY)) ///
	xtick(516(24)624) /// title("Number of Entrants around Policy Discontinuity")
	note("Vertical line denotes availability of 1603 cash grant for wind farms entering after January 1, 2009.")
graph export "$outdir/figures/investments_vs_time.png", replace
drop number


********************************************************************************
*CREATE DENSITY GRAPHS
use $repodir/generated_data/panel_reg_data, clear
drop if year < 2013
keep if insample
keep if insample_covars 

local meanvars ptnl_cf_adj wind_speed* nameplate turbsize capacity_factor 
collapse (mean) `meanvars' (min) min_reg_dummy = reg_dummy ///
	(lastnm) ppa_dummy entnum windclass_eia, by(facilityid)
merge 1:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match) 

local yv capacity_factor 
twoway 	(kdensity `yv' if firstyear > 2008  & flag_1603==0, legend(lab(1 "Post-PTC"  )) lwidth(medthick) lcolor(red)  )  ///
		(kdensity `yv' if firstyear > 2008  & flag_1603==1, legend(lab(2 "Post-1603" )) lwidth(medthick) lcolor(blue) ), ///
	 title("Average Capacity Factor by Subsidy Choice - Post 2008") ///
	 note("Capacity factors averaged over 2013-2014 for all cohorts.") ///
	 ylabel(0(.02).07) ytitle("Density") xtitle("Capacity Factor") scheme(s1color)
graph export "$outdir/figures/kdensity_capacity_factor_by_subsidy_post.png", replace

local yv capacity_factor
twoway 	(kdensity `yv' if firstyear > 2008  & flag_1603==0, legend(lab(1 "Post-PTC"  ))			lwidth(medthick) lcolor(red)   )  ///
		(kdensity `yv' if firstyear > 2008  & flag_1603==1, legend(lab(2 "Post-1603" ))			lwidth(medthick) lcolor(blue)  )  ///
		(kdensity `yv' if firstyear < 2009,					legend(lab(3 "Pre-PTC" ) rows(1)) 	lwidth(medthick) lcolor(green) ), ///
	 title("Average Capacity Factor by Subsidy Choice") ///
	 note("Capacity factors averaged over 2013-2014 for all cohorts.") ///
	 ylabel(0(.02).07) ytitle("Density") xtitle("Capacity Factor") scheme(s1color)
graph export "$outdir/figures/kdensity_capacity_factor_by_subsidy.png", replace

********************************************************************************
cap graph close
tempsetup
capture log close
exit
