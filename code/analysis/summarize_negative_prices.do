/* SUMMARIZE NEGATIVE NODAL PRICE DATA
- construct a clean panel of nodes. 
- create summary tables and figures by iso
- correlate with emissions patterns from other papers 

*NOTE THIS USES STATA ADOS grc1leg and egenmore
********************************************************************************/
local fname summarize_negative_prices

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/*******************************************************************************
BRING IN NODE DATA AND DEFINE SAMPLE
*from negative_lmp.do
*******************************************************************************/
clear
foreach iso in ercot miso neiso nyiso pjm caiso {
	append using "$repodir/generated_data/`iso'_negative_lmp.dta"
}
compress
save all_iso_negative_lmp, replace

* GET NODE TYPE INFO AND LAT LONG DATA FROM SNL
*from match_nodes_to_lat_long.do
use "$generated_data/lmp_nodes_with_lat_long.dta", clear
drop if node_in_data == 2 // drop locations not found in LMP data

tostring node_id, gen(my_node_id)
replace my_node_id = node_name if iso != "PJM"
replace my_node_id = subinstr(my_node_id," ","",.)

* CREATE A FLAG FOR GENERATION NODES
gen flag_gen_node = 1
drop gen_node ag_gen_node 
replace flag_gen_node = 0 if iso == "MISO" & type != "Gennode"
replace flag_gen_node = 0 if iso == "PJM" & type != "GEN"
replace flag_gen_node = 0 if iso == "NEISO" & type != "NETWORK NODE"
replace flag_gen_node = 0 if iso == "NYISO" & type != "Generator"

*PJM HAS A BUNCH OF REPEATED NODES
gsort iso node_name node_id -flag_gen_node
bys iso node_name node_id: gen te = _n
drop if te > 1
drop te

gen flag_in_geodata = cond(lat==.,0,1)
rename lat node_lat 
rename long node_long

*drop two duplicates with leading zeros
sort my_node_id node_name
by my_node_id: gen te = _n
drop if te > 1

rename state node_state
keep node_id node_name iso node_lat node_long my_node flag_* node_state
save "$generated_data/node_info.dta", replace

* BRING IN MONTHLY FREQUENCIES BY NODE
use all_iso_negative_lmp, clear
*CREATE A STRING VARIABLE THAT IS NODEID IN PJM AND NODE NAME ELSEWHERE
tostring node_id, gen(my_node_id)
replace my_node_id = node_name if iso != "PJM" // NODE NAME NOT UNIQUE IN PJM
replace my_node_id = subinstr(my_node_id," ","",.)

drop type
merge m:1 my_node_id using "$generated_data/node_info.dta", nogen keep(match) 
tab iso flag_gen_node
drop if year < 2011 | year > 2014 // these are available for each iso
egen nodeobs = count(year), by(my_node_id iso)

rename fract_below_0 frac0
rename fract_below_23 frac23
gen frac_marginal = frac0 - frac23

foreach v of varlist frac0 frac23 frac_marginal {
	replace `v' = `v'*100
}
save mergeddata, replace

use mergeddata, clear
keep if nodeobs == 48 
keep if flag_gen_node == 1 // SOME ISO's have many LMP nodes 
sort my_node_id year month
by my_node: gen flag_firstob = _n
replace flag_firstob = 0 if flag_firstob > 1
save node_data_bymonth, replace

use mergeddata, clear 
keep if flag_gen_node == 1 
keep if flag_in_geodata ==1 &  flag_gen_node == 1
bysort iso node_lat node_long year month: gen te = _n
drop if te > 1
drop te
drop nodeobs my_node_id 
by iso node_lat node_long: gen nodeobs = _N
drop if nodeobs < 48 
by iso node_lat node_long: gen te = _n
keep if te == 1 
bys node_lat node_long: gen tn = _N
tab tn
drop if tn > 1 & iso != "PJM" // a couple duplicates in PJM expanded territory. 
drop te tn 
sort node_lat node_long
gen my_node_id = _n
save agg_node_info, replace // save this to retain actual node name later 

keep node_lat node_long iso my_node_id 
save tempdat, replace

use mergeddata, clear
drop nodeobs my_node_id 
merge m:1 iso node_lat node_long using tempdat, keep(match) nogen

collapse (median) frac0 frac23 frac_marginal lmp_mean lmp_median node_lat node_long ///
	(firstnm) iso , by(my_node_id year month)
sort my_node_id year month
by my_node: gen flag_firstob = _n
replace flag_firstob = 0 if flag_firstob > 1
save aggnode_data_bymonth, replace

/*******************************************************************************
COMPARE HOURLY AND SEASONAL VARIATION TO CALLAWAY PAPER
- THEIR DATA IS 2010 - 2012
- SEASONS ARE SUMMER = MAY - OCTOBER
- stat is marginal OPERATING EMISSION RATE (MOER) (lbs CO2/MWh)
*******************************************************************************/

*IMPORT DATA FROM CALLAWAY ET ALL APPENDIX
import excel using "$dropbox/Data/public/callaway_moer_data/callaway_et_al_appendix_tables.xlsx", ///
	firstrow sheet("forstata") clear
rename California CAISO
rename ISONE NEISO
foreach v in CAISO ERCOT MISO NEISO NYISO PJM {
	rename `v' moer_`v'
}
lab var moer_CAISO CAISO
save "$generated_data/moerdata.dta", replace

*BRING IN HOUR OF DAY FRACTIONS 
use "$generated_data/lmp_hour_of_day_fractions", clear
drop if year == 2010 // this is incomplete for ercot
gen season = cond(month > 4 & month < 11, "summer","winter")
collapse (mean) frac0_ = frac, by(iso season hour)
reshape wide frac0_, i(hour season) j(iso) str

merge 1:1 hour season using "$generated_data/moerdata.dta", nogen keep(match) 
save hourdata, replace

use hourdata, clear
twoway line moer_* hour if season == "summer", saving(moer_summer, replace) ///
	legend(rows(2)) xlabel(0(4)24) xtitle("") subtitle("Summer")
	
twoway line frac0_* hour if season == "summer", saving(np_summer, replace) ///
	legend(rows(2)) xlabel(0(4)24) xtitle("") ylabel(0(.05).15)  subtitle("Summer")
	
twoway line moer_* hour if season == "winter", saving(moer_winter, replace) ///
	legend(rows(2)) xlabel(0(4)24) xtitle("")  subtitle("Winter")
	
twoway line frac0_* hour if season == "winter", saving(np_winter, replace) ///
	legend(rows(2)) xlabel(0(4)24) xtitle("") ylabel(0(.05).15)  subtitle("Winter")


grc1leg  moer_summer.gph moer_winter.gph, /// 
	legendfrom(moer_summer.gph) l1("lbs CO2/ MWh") saving(tm, replace)
	
grc1leg np_summer.gph np_winter.gph , /// 
	legendfrom(np_summer.gph) l1("Negative Price %") saving(tn, replace)

grc1leg  tm.gph tn.gph, /// 
	legendfrom(tm.gph) rows(2) imargin(zero)

graph export "$repodir/output/figures/moer_np_season.png", replace


*GET HOURLY MOER AND CORRELATION FOR DRAFT TABLE
use hourdata, clear
foreach ti in CAISO ERCOT MISO NEISO NYISO PJM {
	gen s_`ti' =  moer_`ti'
}
collapse (mean) s_* 
gen statrow = "moer"
keep statrow s_*
save tempdat, replace

use hourdata, clear
foreach ti in CAISO ERCOT MISO NEISO NYISO PJM {
	gen w_`ti' = frac0_`ti' * moer_`ti'
}
collapse (sum) w_* (sum) frac0* 
foreach ti in CAISO ERCOT MISO NEISO NYISO PJM {
	gen s_`ti' = w_`ti'/frac0_`ti'
}
gen statrow = "moer_wgt"
keep statrow s_*
append using tempdat
save tempdat, replace

use hourdata, clear
foreach ti in CAISO ERCOT MISO NEISO NYISO PJM {
	egen s_`ti' = corr(frac0_`ti' moer_`ti') 
}
collapse (mean) s_*
gen statrow = "corr"
keep statrow s_*
append using tempdat
order statrow s_CAISO s_ERCOT s_NEISO s_MISO s_NYISO s_PJM // alphabetical; NEISO is really named ISONE
save moer_np_summary, replace

/*******************************************************************************
SUMMARIZE DATA BY ISO
- CREATE A DTA FILE THEN A TEX TABLE FOR SUBSET
*******************************************************************************/
*GET BOTTOM DECILE OF NODES IN EACH ISO
use aggnode_data_bymonth, clear
save node_fracs, replace

use node_fracs, replace
collapse (mean) frac*, by(iso my_node_id)

gsort iso -frac0
by iso: gen nrank = _n
egen Nt = count(frac0), by(iso)
gen npct = nrank/Nt
keep npct iso my_node*
save noderank, replace

****************************
*export table with summary stats; make table in excel

capture program drop sumit
program define sumit
collapse (mean) mean_frac0=frac0 mean_frac_marginal=frac_marginal mean_frac23 = frac23 ///
	(p95) p95_frac0=frac0 (p95) p95_frac_marginal=frac_marginal (p95) p95_frac23 = frac23 ///
	(p50) med_frac0=frac0 (p50) med_frac_marginal=frac_marginal (p50) med_frac23 =frac23 , by(iso)
end

use node_fracs, replace
sumit 
gen descript= "all_years"
save sumstats, replace

use node_fracs, replace
keep if month > 4 & month < 11
sumit
gen descript= "summer"
append using sumstats
save sumstats, replace

use node_fracs, replace
keep if year > 2012
sumit
gen descript= "post2012"
append using sumstats
save sumstats, replace

use node_fracs, clear
*merge m:1 iso node_name node_id  using noderank, nogen
merge m:1 iso my_node_id  using noderank, nogen
keep if npct < .1
sumit
gen descript= "bot10pct"
append using sumstats
save sumstats, replace

use node_fracs, clear
*merge m:1 iso node_name node_id  using noderank, nogen
merge m:1 iso my_node_id  using noderank, nogen
keep if npct < .1 & year > 2012
sumit
gen descript= "bot10pct_post2012"
append using sumstats
save sumstats, replace

use node_fracs, clear
*merge m:1 iso node_name node_id  using noderank, nogen
merge m:1 iso my_node_id  using noderank, nogen
keep if npct < .1 & month > 5 & month < 10
sumit
gen descript= "bot10pct_summer"
append using sumstats
save sumstats, replace

order desc iso mean* med* p*
save "$generated_data/negative_price_summary", replace

/*******************************************************************************
*CREATE LATEX TABLE FOR DRAFT
*******************************************************************************/	
use "$generated_data/negative_price_summary", clear
foreach v of varlist mean_* med_* p95_* {
	rename `v' s_`v'
}
reshape long s_, i(iso descript) j(svar) str
gen statrow = descript + "_" + svar
drop descript svar
reshape wide s_, i(statrow) j(iso) str
order statrow s_CAISO s_ERCOT s_NEISO s_MISO s_NYISO s_PJM // alphabetical; NEISO is really named ISONE
save tempdat, replace

*CONVERT TO TEX TABLE
mat tlab = J(1,6,.)
mat cmat = tlab

*SUMMARY FOR ALL NODES
local snames all_years_mean_frac0 all_years_med_frac0 all_years_p95_frac0 ///
	summer_mean_frac0 post2012_mean_frac0
local ns: word count `snames'
di `ns'
mat T = J(`ns',6,.)
local t = 0
foreach v in `snames' {
	di `t'
	local t = 1 + `t' 
	di "`v'"
	use tempdat, clear
	keep if statrow == "`v'"
	di _N
	mkmat s_*, mat(tm)

	forval i= 1/6 {
		mat T[`t',`i'] = tm[1,`i']
	}
}
mat cmat = cmat\T\tlab

*ADD MOERS
local snames moer moer_wgt corr
local ns: word count `snames'
di `ns'
mat T = J(`ns',6,.)
local t = 0
foreach v in `snames' {
	di `t'
	local t = 1 + `t' 
	di "`v'"
	use moer_np_summary, clear
	keep if statrow == "`v'"
	di _N
	mkmat s_*, mat(tm)

	forval i= 1/6 {
		mat T[`t',`i'] = tm[1,`i']
	}
}

mat cmat = cmat\T


mat rownames cmat = "\textbf{\underline{All nodes}}" "Mean" "Median" "95th pctile" ///
					"Summer (mean)" "Post 2012 (mean)" /// 
					"\textbf{\underline{CO2 MOER}}" "Mean" "Mean (weighted)" "Correlation" 

frmttable using "$outdir/tables/negative_price_summary.tex", statmat(cmat) varlabels replace ///
	ctitle("", "CAISO", "ERCOT", "ISONE", "MISO", "NYISO", "PJM") hlines(11{0}1) frag tex  /// 
	sdec(2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ ///
	 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ /// *	 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ 2,2,2,2,2,2 \ ///
	 0,0,0,0,0,0 \ 0,0,0,0,0,0 \  0,0,0,0,0,0 \ 2,2,2,2,2,2)

*	 spacebef(1000010010001000) ///

/*******************************************************************************
COMPARE HOURLY VARIATION TO HMMY (AER 2016)
- stat is average marginal damages of load by NERC region - hour in dollar terms
- includes both local and global pollutants
- they construct these using econometric estimates and integrated assessment model
- we use HMMY's baseline assumptions
Data source: Holland, Stephen P., Erin T. Mansur, Nicholas Z. Muller, and Andrew J. Yates. 2016. "Are There Environmental Benefits from Driving Electric Vehicles? The Importance of Local Factors." American Economic Review, 106 (12): 3700-3729.
*******************************************************************************/
*GOING TO POST THIS DTA NOT THE EXCEL FILE, SO ONLY READ IN RAW DATA ONCE
*code for reading data is from HMMY (AER 2016) with minor modifications needed to run
cap confirm file "$generated_data/md_from_hhmy_aer_2016.dta"
if _rc!=0 { // only read in data the first time
	local SCC 41
	local CPIadj 1.37
	local year= 2011
	use "$dropbox/Data/public/HMMY_AER_2016/MD Veh calcs posted/MDelectric_local_`year'.dta", clear
	merge 1:1 hour using "$dropbox/Data/public/HMMY_AER_2016/MD Veh calcs posted/MDelectric_carbon_`year'.dta"
	foreach X in ercot wecc frcc mro npcc rfc serc spp ca {
		replace `X'=`CPIadj'*(`X')+`SCC'*co2_md_kwh_`X'/35
	}
	drop co2* _merge
	rename * md*
	rename mdhour hour
	reshape long md, i(hour) j(region) string
	replace md = md*1000 // $/kWh to $/MWh
	lab var md "Marginal Damages from HMMY (AER 2016) in 2014 $/MWh"
	sort region hour
	compress
	save "$generated_data/md_from_hhmy_aer_2016.dta", replace
}

*plot marginal damages from load along with PTC value, both in $/MWh
use "$generated_data/md_from_hhmy_aer_2016.dta", clear
replace region = upper(region)
reshape wide md, i(hour) j(region) string
ren md* *
ds hour, not
foreach v of var `r(varlist)' {
	lab var `v' `v'
}
ren * md_*
ren md_hour hour
twoway line md_* hour, ///
	yline(23, lwidth(medthick) lcolor(gs0)) ///
	legend(cols(4)) xtitle("Hour of Day") ///
	xlabel(4(4)24) ///
	ytitle("Average Marginal Damages ($/MWh)")
graph export "$repodir/output/figures/md_np_hmmy.png", replace

********************************************************************************
tempsetup
cd "$repodir" 
capture log close
exit
