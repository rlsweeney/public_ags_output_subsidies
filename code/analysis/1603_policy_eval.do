/*******************************************************************************
1603 PROGRAM EVALUATION 
- FOR 1603 PLANTS GET UNDER 1603 AND PTC TO FIGURE OUT WHICH PLANTS LOOK MARGINAL
********************************************************************************/
local fname 1603_policy_eval

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
** PTC DISCOUNT RATE; OUTPUT SUBSIDY LEVEL ; INVESTMENT SUBSIDY LEVEL ;
** INDICATOR=1 TO SHUT DOWN PTC_RESPONSE ; INDICATOR=1 TO INCLUDE DEPRECIATION

* DEFINE MAIN ASSUMPTIONS 
global baseline $teffect 25 .05 .08 23 .3 0 1
getprofits	$baseline 
tab_profits 

* MAKE TABLE AND SUMMARY MEASURES OF COST EFFECTIVENESS BY GROUP FOR 1603 PLANTS *********************************************
*DEFINE PROGRAM HERE TO USE LATER FOR SENSITIVITY
capture program drop makepolicyevaltable
program define makepolicyevaltable
	args case

	*STATS OF PLANTS BY SGROUP FOR DRAFT TEXT *********************************************
	capture drop _num
	capture drop _text 
	count if sgroup=="PTC only" // plants marginal to the PTC in always group
	gen _num = r(N)
	num2words _num, g(_text)
	local tv = _text[1]
	di "`tv'"
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-ptc-only_N.tex", write text replace 
		file write myfile "`tv'"
	file close myfile
	*if _num==0, this is irrelevant: removing the file here will remove irrelevant footnote from text
	if _num[1]==0 {
		erase "$repodir/output/estimates/pe_`case'_pi-ptc-only_N.tex"
	}

	* ADD PTC ONLY PLANTS TO THE ALWAYS PROFITABLE GROUP FOR EXPOSITION IN THE TEXT 
	replace sgroup="both" if sgroup=="PTC only" // include plants marginal to the PTC in always group

	capture drop _num
	capture drop _text 
	count if sgroup=="both"
	gen _num = r(N)
	local tv = _num[1]
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-always_N.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	capture drop _num
	capture drop _text 
	count if sgroup=="1603 only"
	gen _num = r(N)
	local tv = _num[1]
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-1603-only_N.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	capture drop _num
	capture drop _text 
	capture drop marginal
	gen marginal = cond(sgroup == "1603 only",1,0)
	sum marginal, detail
	gen _num = round(r(mean)*100)
	num2words _num, g(_text)
	local tv = _text[1]
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-1603-only_Pct.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	summ dQ_1603 if sgroup=="1603 only"
	local tv = round(r(N)*r(mean)/1000000)
	disp `tv'
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-1603-only_dQ.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	capture drop _num
	capture drop _text 
	count if sgroup=="neither"
	gen _num = r(N)
	num2words _num, g(_text)
	local tv = _text[1]
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-never_N.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	gen never = cond(sgroup == "neither",1,0)
	sum never, detail
	local tv = round(r(mean)*100)
	file open myfile using "$repodir/output/estimates/pe_`case'_pi-never_Pct.tex", write text replace 
		file write myfile "`tv'"
	file close myfile

	* MAKE TABLE OF COST EFFECTIVENESS BY GROUP FOR 1603 PLANTS *********************************************
	capture drop nobs
	gen nobs =1

	*NEED TO CALCULATE AVERAGE PUB EXP HERE (OTHERWISE ITS SIMPLE AVERAGE IN TABLE)
	egen ggen = sum(dQ_1603), by(sgroup)
	egen gdol = sum(pubexp_1603), by(sgroup)
	gen plcoe_1603 = gdol/ggen
	drop ggen gdol
	egen ggen = sum(dQ_ptc), by(sgroup)
	egen gdol = sum(pubexp_ptc), by(sgroup)
	gen plcoe_ptc = gdol/ggen
	drop ggen gdol

	*CREATE LABELS THAT MATCH TEXT
	gen slabel  = "Always Profitable"
	replace slabel = "Marginal" if sgroup == "1603 only"
	replace slabel = "Never Profitable" if sgroup == "neither"

	*convert units for table
	foreach v of varlist dQ_* pubexp* {
		replace `v' = `v'/1000000
	}
	tabout slabel using $repodir/output/tables/policyevaltab_`case'.tex, ///
	c(sum nobs  sum dQ_1603 sum pubexp_1603 mean plcoe_1603 ///
		sum dQ_ptc sum pubexp_ptc  mean plcoe_ptc) ///
	f(0c 0c 0c 2 0c 0c 2) ///
	rep sum ///
	style(tex) bt ///
	topf($repodir/code/analysis/top.tex) topstr(\textwidth) ptotal(none) total(none) botf($repodir/code/analysis/bot.tex) ///
	h1(nil) ///
	cl2(3-5 6-8) h2( & & \multicolumn{3}{c}{1603} & \multicolumn{3}{c}{PTC} \\ ) ///
	h3(Group & N & Output (MMWh) & Subsidy (\textdollar M) & Subsidy (\textdollar/MWh) ///
		& Output (MMWh) & Subsidy (\textdollar M) & Subsidy (\textdollar/MWh) \\ )


	*CALCULATE SUMMARY MEASURES FOR DRAFT TEXT *********************************************
	collapse (sum) nobs (sum) dQ_1603 (sum) pubexp_1603 (mean) plcoe_1603 (sum) dQ_ptc (sum) pubexp_ptc (mean) plcoe_ptc, by(sgroup)
	save tempdat, replace

	use tempdat, clear
	gen assumption = "Marginal"

	foreach v of varlist dQ_ptc pubexp_ptc {
		replace `v' = . if sgroup == "1603 only"
		replace `v' = . if sgroup == "neither"
	}
	save sdat, replace

	use tempdat, clear
	gen assumption = "Always"

	foreach v of varlist dQ_ptc pubexp_ptc {
		replace `v' = . if sgroup == "1603 only"
	}
	append using sdat

	collapse (sum) dQ_* pubexp*, by(assumption)

	gen dQ_diff = dQ_1603 - dQ_ptc
	gen dQ_diff_pct = dQ_diff/ dQ_ptc

	gen C_diff = pubexp_1603 - pubexp_ptc
	gen C_diff_pct = C_diff/ pubexp_ptc

	gen lcoe_1603 = pubexp_1603/dQ_1603
	gen lcoe_ptc = pubexp_ptc/dQ_ptc

	gen lcoe_diff = lcoe_1603 - lcoe_ptc
	gen lcoe_diff_pct = lcoe_diff/lcoe_ptc

	replace dQ_diff = round(dQ_diff)
	replace C_diff = round(C_diff)

	replace dQ_diff_pct = round(dQ_diff_pct*100)
	replace C_diff_pct = round(C_diff_pct*100)

	replace lcoe_diff = round(lcoe_diff, .01)
	replace lcoe_1603 = round(lcoe_1603, .01)
	replace lcoe_ptc = round(lcoe_ptc, .01)

	replace lcoe_diff_pct = round(lcoe_diff_pct*100)

	save policy_sums, replace

	*EXPORT TEX FILES WITH NUMBERS FOR DRAFT
	use policy_sums, clear
	sort assumption
	
	foreach v of varlist dQ_* {
		replace `v' = -`v' if _n == 1 // this reverses the sign on numbers for the case where never profitable plants are treated as always profitable
	}

	*VARS WITH NO DECIMALS IN TEXT
	foreach v of varlist dQ_diff* C_diff* lcoe_diff_pct {
		local tlab = "Always"
		local tv = trim("`: display %10.0fc `v'[1]'") // FC ADDS COMMAS
		di `tv'

		di "`v' - `tlab'  =   `tv'"

		file open myfile using "$repodir/output/estimates/pe_`case'_`tlab'_`v'.tex", write text replace 
		file write myfile "`tv'"
		file close myfile

		local tlab = "Marginal"
		local tv = trim("`: display %10.0fc `v'[2]'")
		di `tv'
		di "`v' - `tlab'  =   `tv'"

		file open myfile using "$repodir/output/estimates/pe_`case'_`tlab'_`v'.tex", write text replace 
		file write myfile "`tv'"
		file close myfile
	}

	*VARS WITH 2 DECIMALS IN TEXT
	foreach v of varlist lcoe_diff lcoe_1603 lcoe_ptc {
		local tlab = "Always"
		local tv = trim("`: display %10.2fc `v'[1]'") // FC ADDS COMMAS
		di `tv'

		di "`v' - `tlab'  =   `tv'"

		file open myfile using "$repodir/output/estimates/pe_`case'_`tlab'_`v'.tex", write text replace 
		file write myfile "`tv'"
		file close myfile

		local tlab = "Marginal"
		local tv = trim("`: display %10.2fc `v'[2]'")
		di `tv'
		di "`v' - `tlab'  =   `tv'"

		file open myfile using "$repodir/output/estimates/pe_`case'_`tlab'_`v'.tex", write text replace 
		file write myfile "`tv'"
		file close myfile
	}
end

* BASELINE RESULTS ***************************************************
getprofits	$baseline 
keep if flag_1603==1

* MAKE FIGURES
set scheme s1color
twoway (scatter pi_ptc pi_1603, /// 
			yline(0, lcolor(black) lwidth(thin)) ///
			xline(0, lcolor(black) lwidth(thin)) ///
			msymbol(o) msize(small)) ///
		(function y = x, lcolor(cranberry) range(-2 5) ///
					xlab(-2(2)5)  ylab(-2(2)5) legend(off) /// 
		ytitle("PTC Profits (million $ / MW)") xtitle("1603 Profits (million $ / MW)")) 

graph export "$repodir/output/figures/1603_vs_PTC_pi_scatter.png", replace		

* MAKE TABLE	
makepolicyevaltable baseline

*MAKE SENSITIVITY TABLES ***************************************************
* use .105 instead of .08 to discount ptc revenues
getprofits	$teffect 25 .05 .105 23 .3 0 1
keep if flag_1603==1
makepolicyevaltable highrtax

********************************************************************************
cap graph close
tempsetup
capture log close
exit
