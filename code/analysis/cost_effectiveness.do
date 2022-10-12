/*******************************************************************************
GENERIC COST EFFECTIVENESS COMPARISON 
- CALCULATE COST CONDITIONAL ON QUANTITY ACROSS SUBSIDY TYPES 
********************************************************************************/
local fname cost_effectiveness

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/* RUN POLICY EVAL DATA PREP ***************************************************
- CLEANS DATA; 
- ASSIGNS TE FROM ESTIMATES; 
- DEFINES A PROGRAM TO COMPUTE DISCOUNTED PROFITS */

do "$repodir/code/analysis/prep_policyeval.do"

*FUNCTION INPUTS: 
** TEFFECT ; NUMBER OF YEARS ; ANNUAL DISCOUNT RATE ; 
** PTC VALUATION (%); OUTPUT SUBSIDY LEVEL ; INVESTMENT SUBSIDY LEVEL ;
** INDICATOR=1 TO SHUT DOWN PTC_RESPONSE ; INDICATOR=1 TO INCLUDE DEPRECIATION

* DEFINE MAIN ASSUMPTIONS 
* HERE REMOVE ALL DIFFERENTIAL TAX TREATMENT (OUTPUT SUBSIDY AS CASH AND NO DIFFERENTIAL DEPRECIATION)
getprofits $teffect 25 .05 .05 23 .3 0 0
tab_profits 

tab flag_1603, matcell(tm)
mat list tm
local N_CostEffectiveness_PTC = tm[1,1]
local N_CostEffectiveness_1603 = tm[2,1]

file open myfile using "$repodir/output/estimates/N_CostEffectiveness_PTC.tex", write text replace 
file write myfile "`N_CostEffectiveness_PTC'"
file close myfile

file open myfile using "$repodir/output/estimates/N_CostEffectiveness_1603.tex", write text replace 
file write myfile "`N_CostEffectiveness_1603'"
file close myfile

tab flag_1603 flag_cost_estimated, matcell(tm)
local N_CostEffectiveness_PTC_missing = tm[1,2]
file open myfile using "$repodir/output/estimates/N_CostEffectiveness_PTC_missing.tex", write text replace 
file write myfile "`N_CostEffectiveness_PTC_missing'"
file close myfile

*GENERIC COST-EFFECTIVENESS COMPARISON *****************************************
* ASSUMPTIONS: 
** - NO DEPRECIATION 
** - KEEP NEVER PROFITABLE PLANTS AND INFRAMARGINAL 

* get never profitable plants 
tempfile never_profitable
getprofits $teffect 25 .05 .05 23 .3 0 0
tab_profits 
keep if pi_ptc<0 & pi_1603<0
gen never_profitable = 1
keep facilityid never_profitable ptc_pref
save `never_profitable'

*PTC WITH OUTPUT RESPONSE
forval phi = 0(0.23)23.01 {
	qui{
		getprofits	$teffect 25 .05 .05 `phi' .3 0 0
		merge 1:1 facilityid using `never_profitable'
		keep if pi_ptc >= 0 | never_profitable==1
		gen phi = `phi'
		collapse (sum) dQ=dQ_ptc pubexp_ptc, by(phi flag_1603)
		gen plcoe_ptc  = pubexp_ptc / dQ
		if `phi'==0{
			tempfile ptc
			save `ptc', replace
		}
		else{
			append using `ptc'
			save `ptc', replace
		}
	}
}

*PTC WITHOUT OUTPUT RESPONSE
forval phi = 0(0.23)23.01 {
	qui{ 
		getprofits	$teffect 25 .05 .05 `phi' .3 1 0 // second to last indicator=1 shuts down treatment effect of output subsidy
		merge 1:1 facilityid using `never_profitable'
		keep if pi_ptc >= 0 | never_profitable==1
		gen phi = `phi'
		collapse (sum) dQ=dQ_ptc pubexp_ptc_noTE=pubexp_ptc, by(phi flag_1603)
		gen plcoe_ptc_noTE  = pubexp_ptc_noTE / dQ
		if `phi'==0{
			tempfile ptc_noTE
			save `ptc_noTE', replace
		}
		else{
			append using `ptc_noTE'
			save `ptc_noTE', replace
		}
	}
}

*1603
forval s = 0(0.003)0.3001 {
	qui{
		getprofits	$teffect 25 .05 .05 23 `s' 0 0
		merge 1:1 facilityid using `never_profitable'
		keep if pi_1603 >= 0 | never_profitable==1
		gen s = `s'
		collapse (sum) dQ=dQ_1603 pubexp_1603, by(s flag_1603)
		gen plcoe_1603  = pubexp_1603 / dQ
		if `s'==0{
			tempfile 1603
			save `1603', replace
		}
		else{
			append using `1603'
			save `1603', replace
		}
	}
}

*COMBINE RESULTS
append using `ptc'
append using `ptc_noTE'
sort flag_1603 s phi

replace dQ = dQ / 1e6

gen case = "1603" if s!=.
replace case = "PTC" if phi!=. & plcoe_ptc!=.
replace case = "PTC - no TE" if phi!=. & plcoe_ptc_noTE!=.

save plotdat, replace

*PLOT 1603 PLANTS
use plotdat, clear
keep if flag_1603==1
twoway line plcoe_1603 dQ if case=="1603", lcolor(dkgreen) ///
	|| line plcoe_ptc_noTE dQ if case=="PTC - no TE", lpattern(shortdash) lcolor(navy) ///
	|| line plcoe_ptc dQ if case=="PTC", lpattern(longdash) lcolor(navy) ///
	|| scatter plcoe_1603 dQ if round(s, 0.0001)==0.3 & case=="1603", msymbol(circle) color(dkgreen) ///
	|| scatter plcoe_ptc dQ if round(phi,0.001)==23 & case=="PTC", msymbol(circle) color(navy) ///
	, ytitle("Public LCOE ($/MWh)") xtitle("Electricity Generation (TWh)") ylabel(0(5)20) /// note("1603 recipients only.")
	legend(order(1 "Investment" 2 "Output - Fixed Q" 3 "Output" 4 "Observed Subsidy Level"))
graph export "$repodir/output/figures/plcoe_plot_1603plants.png", replace

*PLOT PTC PLANTS
use plotdat, clear
keep if flag_1603==0
twoway line plcoe_1603 dQ if case=="1603", color(dkgreen) ///
	|| line plcoe_ptc_noTE dQ if case=="PTC - no TE", lpattern(shortdash) color(navy) ///
	|| line plcoe_ptc dQ if case=="PTC", lpattern(longdash) color(navy) ///
	|| scatter plcoe_1603 dQ if round(s, 0.0001)==0.3 & case=="1603", msymbol(circle) color(dkgreen) ///
	|| scatter plcoe_ptc dQ if round(phi,0.001)==23 & case=="PTC", msymbol(circle) color(navy) ///
	, ytitle("Public LCOE ($/MWh in PDV terms)") xtitle("Electricity Generation (TWh in PDV terms)") ///
	legend(order(1 "Investment" 2 "Output - Fixed Q" 3 "Output" 4 "Observed Subsidy Level")) note("PTC recipients only.")
* graph export "$repodir/output/figures/plcoe_plot_PTCplants.png", replace

*PLOT PLANTS TOGETHER
use plotdat, clear
collapse (sum) dQ pubexp*, by(case phi s)
gen plcoe_1603 = pubexp_1603/(dQ*1e6)
gen plcoe_ptc = pubexp_ptc/(dQ*1e6)
gen plcoe_ptc_noTE = pubexp_ptc_noTE/(dQ*1e6)


save plotdat_all, replace

twoway line plcoe_1603 dQ if case=="1603", color(dkgreen) ///
	|| line plcoe_ptc_noTE dQ if case=="PTC - no TE", lpattern(shortdash) color(navy) ///
	|| line plcoe_ptc dQ if case=="PTC", lpattern(longdash) color(navy) ///
	|| scatter plcoe_1603 dQ if round(s, 0.0001)==0.3 & case=="1603", msymbol(circle) color(dkgreen) ///
	|| scatter plcoe_ptc dQ if round(phi,0.001)==23 & case=="PTC", msymbol(circle) color(navy) ///
	, ytitle("Public LCOE ($/MWh)") xtitle("Electricity Generation (TWh)") ylabel(0(5)20) ///
	legend(order(1 "Investment" 2 "Output - Fixed Q" 3 "Output" 4 "Observed Subsidy Level"))
graph export "$repodir/output/figures/plcoe_plot_all.png", replace

*SUMMARY MEASURES FOR TEXT *****************************************


*MMWh WITH NO SUBSIDY
use plotdat, clear
keep if flag_1603==1 & s==0
replace dQ = 100*floor(dQ/100) // not ideal but floor doesn't take a second argument like round
local ce_nosubsidy_dQ = dQ
file open myfile using "$repodir/output/estimates/ce_nosubsidy_dQ.tex", write text replace 
file write myfile "`ce_nosubsidy_dQ'"
file close myfile


*GET OUTPUT SUBSIDY (phi=?) THAT IS EQUIVALENT IN MMWh TO ACTUAL SUBSIDY (s=.3)

** 1603 PLANTS ONLY ---------------
*1603 case numbers
use plotdat, clear
keep if flag_1603==1 & round(s, 0.0001)==0.3
local ce_1603_dQ = dQ
local ce_1603_plcoe = round(plcoe_1603,0.01)
file open myfile using "$repodir/output/estimates/ce_1603_plcoe.tex", write text replace 
file write myfile "`ce_1603_plcoe'"
file close myfile

*PTC case numbers
use plotdat, clear
keep if flag_1603==1 & case=="PTC"
gen dQ_diff = abs(dQ - `ce_1603_dQ')
egen min_dQ_diff = min(dQ_diff)
keep if min_dQ_diff==dQ_diff

local ce_1603equivalentPTC_phi = round(phi,0.01)
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_phi.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_phi'"
file close myfile

local ce_1603equivalentPTC_plcoe = round(plcoe_ptc,0.01)
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_plcoe.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_plcoe'"
file close myfile

* relative cost per MMWh
local ce_1603equivalentPTC_plcoe_pct = round( (`ce_1603_plcoe' - `ce_1603equivalentPTC_plcoe') / `ce_1603_plcoe' * 100 )
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_plcoe_pct.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_plcoe_pct'"
file close myfile

** ALL PLANTS---------------
*1603 case numbers
use plotdat_all, clear
keep if round(s, 0.0001)==0.3
local ce_1603_dQ = dQ
local ce_1603_plcoe = round(plcoe_1603,0.01)
file open myfile using "$repodir/output/estimates/ce_1603_plcoe_allplants.tex", write text replace 
file write myfile "`ce_1603_plcoe'"
file close myfile

*PTC case numbers
use plotdat_all, clear
keep if case=="PTC"
gen dQ_diff = abs(dQ - `ce_1603_dQ')
egen min_dQ_diff = min(dQ_diff)
keep if min_dQ_diff==dQ_diff

local ce_1603equivalentPTC_phi = round(phi,0.01)
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_phi_allplants.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_phi'"
file close myfile

local ce_1603equivalentPTC_plcoe = round(plcoe_ptc,0.01)
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_plcoe_allplants.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_plcoe'"
file close myfile

* relative cost per MMWh
local ce_1603equivalentPTC_plcoe_pct = round( (`ce_1603_plcoe' - `ce_1603equivalentPTC_plcoe') / `ce_1603_plcoe' * 100 )
file open myfile using "$repodir/output/estimates/ce_1603equivalentPTC_plcoe_pct_allplants.tex", write text replace 
file write myfile "`ce_1603equivalentPTC_plcoe_pct'"
file close myfile

*GET 1603 SUBSIDY (s=?) THAT IS EQUIVALENT IN MMWh TO PTC-noTE at $23/MWh
*PTC - no TE case numbers
use plotdat, clear
keep if flag_1603==1 & phi==23 & case=="PTC - no TE"
local ce_PTCnoTE_dQ = dQ
local ce_PTCnoTE_plcoe = round(plcoe_ptc_noTE,0.01)
file open myfile using "$repodir/output/estimates/ce_PTCnoTE_plcoe.tex", write text replace 
file write myfile "`ce_PTCnoTE_plcoe'"
file close myfile

*1603 case numbers
use plotdat, clear
keep if flag_1603==1 & case=="1603"
gen dQ_diff = abs(dQ - `ce_PTCnoTE_dQ')
egen min_dQ_diff = min(dQ_diff)
keep if min_dQ_diff==dQ_diff
sort s
keep in 1 // minimum subsidy that achieves dQ

local ce_PTCnoTEequivalent1603_s = round(s,0.01)
file open myfile using "$repodir/output/estimates/ce_PTCnoTEequivalent1603_s.tex", write text replace 
file write myfile "`ce_PTCnoTEequivalent1603_s'"
file close myfile

local ce_PTCnoTEequivalent1603_plcoe = round(plcoe_1603,0.01)
file open myfile using "$repodir/output/estimates/ce_PTCnoTEequivalent1603_plcoe.tex", write text replace 
file write myfile "`ce_PTCnoTEequivalent1603_plcoe'"
file close myfile


/*******************************************************************************
ROBUSTNESS ANALYSIS: SET PRICE-INVESTMENT PRODUCTIVITY CORRELATION TO ZERO
SPECIFICALLY: SET OUTPUT PRICES EQUAL TO SAMPLE AVERAGE PRICE
*******************************************************************************/

use policyEvalData, replace

rename avg_p plant_p
egen avg_p = mean(plant_p)

save policyEvalData, replace

*GENERIC COST-EFFECTIVENESS COMPARISON *****************************************
* ASSUMPTIONS: 
** - NO DEPRECIATION 
** - KEEP NEVER PROFITABLE PLANTS AND INFRAMARGINAL 

* get never profitable plants 
tempfile never_profitable
getprofits $teffect 25 .05 .05 23 .3 0 0
tab_profits 
keep if pi_ptc<0 & pi_1603<0
gen never_profitable = 1
keep facilityid never_profitable ptc_pref
save `never_profitable'

*PTC WITH OUTPUT RESPONSE
forval phi = 0(0.23)23.01 {
	qui{
		getprofits	$teffect 25 .05 .05 `phi' .3 0 0
		merge 1:1 facilityid using `never_profitable'
		keep if pi_ptc >= 0 | never_profitable==1
		gen phi = `phi'
		collapse (sum) dQ=dQ_ptc pubexp_ptc, by(phi flag_1603)
		gen plcoe_ptc  = pubexp_ptc / dQ
		if `phi'==0{
			tempfile ptc
			save `ptc', replace
		}
		else{
			append using `ptc'
			save `ptc', replace
		}
	}
}

*PTC WITHOUT OUTPUT RESPONSE
forval phi = 0(0.23)23.01 {
	qui{ 
		getprofits	$teffect 25 .05 .05 `phi' .3 1 0 // second to last indicator=1 shuts down treatment effect of output subsidy
		merge 1:1 facilityid using `never_profitable'
		keep if pi_ptc >= 0 | never_profitable==1
		gen phi = `phi'
		collapse (sum) dQ=dQ_ptc pubexp_ptc_noTE=pubexp_ptc, by(phi flag_1603)
		gen plcoe_ptc_noTE  = pubexp_ptc_noTE / dQ
		if `phi'==0{
			tempfile ptc_noTE
			save `ptc_noTE', replace
		}
		else{
			append using `ptc_noTE'
			save `ptc_noTE', replace
		}
	}
}

*1603
forval s = 0(0.003)0.3001 {
	qui{
		getprofits	$teffect 25 .05 .05 23 `s' 0 0
		merge 1:1 facilityid using `never_profitable'
		keep if pi_1603 >= 0 | never_profitable==1
		gen s = `s'
		collapse (sum) dQ=dQ_1603 pubexp_1603, by(s flag_1603)
		gen plcoe_1603  = pubexp_1603 / dQ
		if `s'==0{
			tempfile 1603
			save `1603', replace
		}
		else{
			append using `1603'
			save `1603', replace
		}
	}
}

*COMBINE RESULTS
append using `ptc'
append using `ptc_noTE'
sort flag_1603 s phi

replace dQ = dQ / 1e6

gen case = "1603" if s!=.
replace case = "PTC" if phi!=. & plcoe_ptc!=.
replace case = "PTC - no TE" if phi!=. & plcoe_ptc_noTE!=.

save plotdat, replace

*PLOT 1603 PLANTS
use plotdat, clear
keep if flag_1603==1
twoway line plcoe_1603 dQ if case=="1603", lcolor(dkgreen) ///
	|| line plcoe_ptc_noTE dQ if case=="PTC - no TE", lpattern(shortdash) lcolor(navy) ///
	|| line plcoe_ptc dQ if case=="PTC", lpattern(longdash) lcolor(navy) ///
	|| scatter plcoe_1603 dQ if round(s, 0.0001)==0.3 & case=="1603", msymbol(circle) color(dkgreen) ///
	|| scatter plcoe_ptc dQ if round(phi,0.001)==23 & case=="PTC", msymbol(circle) color(navy) ///
	, ytitle("Public LCOE ($/MWh)") xtitle("Electricity Generation (TWh)") ylabel(0(5)20) /// note("1603 recipients only.")
	legend(order(1 "Investment" 2 "Output - Fixed Q" 3 "Output" 4 "Observed Subsidy Level"))
graph export "$repodir/output/figures/plcoe_plot_1603plants_meanprice.png", replace

*PLOT PLANTS TOGETHER
use plotdat, clear
collapse (sum) dQ pubexp*, by(case phi s)
gen plcoe_1603 = pubexp_1603/(dQ*1e6)
gen plcoe_ptc = pubexp_ptc/(dQ*1e6)
gen plcoe_ptc_noTE = pubexp_ptc_noTE/(dQ*1e6)

save plotdat_all, replace

twoway line plcoe_1603 dQ if case=="1603", color(dkgreen) ///
	|| line plcoe_ptc_noTE dQ if case=="PTC - no TE", lpattern(shortdash) color(navy) ///
	|| line plcoe_ptc dQ if case=="PTC", lpattern(longdash) color(navy) ///
	|| scatter plcoe_1603 dQ if round(s, 0.0001)==0.3 & case=="1603", msymbol(circle) color(dkgreen) ///
	|| scatter plcoe_ptc dQ if round(phi,0.001)==23 & case=="PTC", msymbol(circle) color(navy) ///
	, ytitle("Public LCOE ($/MWh)") xtitle("Electricity Generation (TWh)") ylabel(0(5)20) ///
	legend(order(1 "Investment" 2 "Output - Fixed Q" 3 "Output" 4 "Observed Subsidy Level"))
graph export "$repodir/output/figures/plcoe_plot_all_meanprice.png", replace


********************************************************************************
cap graph close
tempsetup
capture log close
exit
