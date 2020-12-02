/*******************************************************************************
THIS FILE ARRANGES DATA TO CALCULATE DISCOUNTED PROFITS BY PLANT FOR EACH SUBSIDY

OVERVIEW: 

# DATA PREP
- Need to get firm prices (including PPAs and RECs)
- Bring in capital costs (and estimates)
- Fix / standardize units and collapse 

# PROGRAM PREP
- write program that maps this data into discounted profit and q estimates 
for different assumptions 
********************************************************************************/
local fname prep_policyeval

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

*SET GLOBAL ASSUMPTION PARAMETERS **********************************************
** [ not actually using these in this code, but going to call this file 
** at the top of derivative code ]

eststo clear
estimates use  "$outdir/estimates/rd_main_spec.ster" //IV estimate
local te_iv = _b[flag_1603]
estimates use  "$outdir/estimates/match_main_spec.ster" //IV estimate
local te_match = _b[flag_1603]
global teffect = -1*(`te_iv' + `te_match')/200

/*******************************************************************************
DATA PREP 
*******************************************************************************/

*READ IN DEFLATOR *************************************************************
use $repodir/generated_data/deflators, clear
rename year firstyear
save fdeflator, replace 

*GET PPAs *************************************************************
** [ these don't vary month to month, so need to clean then merge with panel ]

use $repodir/generated_data/static_reg_data, clear
*PARSE PPA PRICES
split pparate, parse(",") gen(tp_)
destring tp_*, force replace
egen pparate_max = rowmax(tp_*)
egen pparate_med = rowmedian(tp_*)
drop tp_*

merge 1:1 facilityid using $repodir/generated_data/external_data_all, nogen keep(match master)

capture drop p_ppa
egen p_ppa = rowmax(pparate_med PPA_bnef_median) 

*put in real dollars based on first year 
merge m:1 firstyear using fdeflator, nogen keep(match master) 

replace p_ppa = p_ppa*gdp_deflator2014 if gdp_deflator != .

keep facilityid p_ppa

save ppa_data, replace


* MERGE THESE INTO MONTHLY PANEL; CLEAN PRICES ***********************************

use $repodir/generated_data/panel_reg_data, clear

merge m:1 facilityid using ppa_data, nogen keep(match master)

* CLEAN MONTHLY PRICES **************************************

** RETAIL PRICES ARE CENTS PER KWH
replace state_avg_price = state_avg_price*10

** REC PRICES 
** [ cleaned in `build/rec_prep.do` ]
gen p_rec = cond(rec_price != .,rec_price,0)
gen p_rec_exp = cond(expected_rec != .,expected_rec,0)

** IOWA ALSO HAS A $15/mwh state level tax credit
** https://iub.iowa.gov/renewable-energy-tax-credits **
replace p_rec = p_rec + 15 if state =="IA" & age <=120
replace p_rec_exp = p_rec_exp + 15 if state =="IA" & age <=120

** PUT PRICES IN REAL TERMS 
** [ASSUMING REC PRICE NOMINAL ]
merge m:1 year using $repodir/generated_data/deflators, nogen keep(match master)

foreach v of varlist price_resale_EIA state_avg_price p_rec* {
	replace `v' = `v'*gdp_deflator
}

** FILL IN MISSING PRICES WITH FACILITY AVERAGE
capture drop tk
egen tk = mean(price_resale_EIA), by(facilityid)
replace price_resale_EIA = tk if price_resale_EIA == .

** SOME FIRMS HAVE NON-RESALE SALES. 
** GIVING THEM THE AVERAGE RETAIL PRICE IN STATE

gen frac_resale = salesforresale /  totaldisposition
replace frac_resale = 0 if totaldisp > 0 & totaldisp != . & frac_res == .
replace frac_resale = 1 if frac_resale > 1 & frac_resale != .
capture drop tk 
egen tk = mean(frac_resale), by(facilityid)
replace frac_resale = tk if frac_resale == .
drop tk 

gen avg_price = frac_resale * price_resale + (1-frac_resale) * state_avg_price
replace avg_price = state_avg_price if frac_resale==0

* FOR CALCULATING PROFITS, SET PRICE EQUAL TO THE MAX OF EIA RESALE OR PPA 
egen p_max = rowmax(avg_price p_ppa)
gen p = p_max + p_rec_exp 

** calculate share non-missing prices 
gen pmiss = cond(avg_price == . | avg_price == 0,1,0)
egen npmiss = sum(pmiss), by(facilityid)
bys facilityid: gen ni = _N
gen pct_p_missing = npmiss/ni 
drop pmiss npmiss 

** PUT CAPACITY FACTOR IN PCT 
replace capacity_factor = capacity_factor/100

order facilityid year month age flag_1603 avg_price p_* /// 
		capacity_factor monthcap nameplate_capacity 

sort facilityid year month

** RESTRICT SAMPLE
** [ insample;  plantS observed through 2014]

keep if insample
egen maxyear = max(year), by(facilityid)
keep if maxyear == 2014

drop if pct_p_missing > .5 
drop if facilityid == 57566 // this one missing price data for a year 

** RESTRICT TO PLANTS ENTERING DURING THE 1603 PERIOD 
** [not using the others for anything at the momemnt]
keep if firstyear >= 2009 & firstyear <= 2012

save revdata, replace


* COLLAPSE AVERAGE PRICE AND CAPACITY FACTOR  ********************************************************************

use revdata, clear

gen tc = capacity_factor*p
collapse (sum) tc tk = capacity_factor (mean) capacity_factor, by(facilityid) 

gen avg_p = tc/tk
drop tk tc 

*MERGE IN PLANT CHARACTERISTICS
merge 1:1 facilityid using $repodir/generated_data/static_reg_data, nogen keep(match master)
merge 1:1 facilityid using $repodir/generated_data/cost_estimates, nogen keep(match master)
merge 1:1 facilityid using ppa_data, nogen keep(match master)

*use estimated costs where not observed
gen flag_cost_estimated = cond(cost_mw == . | costsample == 0,1,0)
replace cost_mw = cost_mw_est if flag_cost_estimated == 1

save policyEvalData, replace

/*******************************************************************************
PROGRAM PREP 
*******************************************************************************/

* GET PROFITS ******************************************************************
** this program estimates everything per mw, which can be immediately be related to the te 

capture program drop getprofits
program define getprofits
	args teffect nyears rfirm rptc output_subsidy capital_subsidy noTE include_depreciation

* TEFFECT ; NUMBER OF YEARS ; ANNUAL DISCOUNT RATE ; 
** PTC DISCOUNT RATE; OUTPUT SUBSIDY LEVEL ; INVESTMENT SUBSIDY LEVEL ;
* INDICATOR=1 TO SHUT DOWN PTC_RESPONSE ; INDICATOR=1 TO INCLUDE DEPRECIATION
	
qui{

	use policyEvalData, clear
	
	local lifemonths = `nyears'*12
	local mrate = (1+`rfirm')^(1/12)-1 // monthly equivalent of annual rate when compounded
	local mrate_ptc = (1+`rptc')^(1/12)-1 // monthly equivalent of annual rate when compounded
	local ptcresponse = `teffect'*`output_subsidy'/23  // linearly scales treatment effect 
	if(`noTE'==1){
			local ptcresponse = 0
	}
	
	*get annuity factors 
	gen df_an_T = (1 - (1 + `mrate')^(-`lifemonths'))/`mrate' 
	gen df_an_10 = (1 - (1 + `mrate')^(-120))/`mrate'
	gen df_an_10_ptc = (1 - (1 + `mrate_ptc')^(-120))/`mrate_ptc'

	* 1603 REVENUES *************************************************************
	*adjust observed cf by scaled TE 
	** all these plants are pre 10 years 
	** so PTC plants need to be adjusted down by te to for 1603 
	
	gen cf_1603 = capacity_factor 
	replace cf_1603 = cf_1603 - `teffect' if flag_1603 == 0

	* use capacity factor and annuity to get discounted quantity per mw over 25 years
	* [730 is average number of hours in a month 8760/12]
	gen dQ_1603 = cf_1603 * 730 * df_an_T // d signifies "discounted" ; "delta" is change 
	gen lcoe_1603 = cost_mw*1000000/dQ_1603
	
	gen dRev_1603_mw = dQ_1603 * avg_p/1000000 
	
	* PTC REVENUES *************************************************************
	** for ptc, teffect yields ptcresponse more output for 10 years 
	gen delta_dQ_ptc = `ptcresponse' * 730 * df_an_10
	gen dQ_ptc = dQ_1603 + delta_dQ_ptc

	gen lcoe_ptc = cost_mw*1000000/dQ_ptc
	
	* get additional revenues under ptc (on marginal and inframarginal output)
	gen p_ptc = `output_subsidy' // scale ptc revenue down in nominal terms 
	
	* on marginal output, assume net revenue is half the marginal price times the marginal quantity	
	* discount these streams at the PTC discount rate, to get implied ammount of upfront "revenue" (investment) 
	gen netrev_ptc_marginal = .5 * p_ptc * `ptcresponse' * 730 * df_an_10_ptc
	gen rev_ptc_infra = p_ptc*cf_1603*730 * df_an_10_ptc

	gen dRev_PTC_mw = dRev_1603_mw + (rev_ptc_infra + netrev_ptc_marginal)/1000000

	*these are just for summarizing the effective average price under the ptc
	gen d_rev_ptc_infra = rev_ptc_infra/dQ_ptc
	gen d_rev_ptc_marginal = netrev_ptc_marginal/dQ_ptc
	gen avg_p_ptc = avg_p + d_rev_ptc_infra + d_rev_ptc_marginal

	save policyRevenues, replace
	
	*O&M COSTS
	use $repodir/generated_data/deflators, clear
	keep if year==2018
	local om_deflator = gdp_deflator2014
	
	use policyRevenues, clear
	capture drop fixedOMkWyear 
	gen fixedOMkWyear = 29 * `om_deflator' // FROM 2018 DOE WTMR, DEFLATED TO 2014 DOLLARS
	
	gen fom_mw = fixedOMkWyear/12*1000 * df_an_T / 1000000
	
	*PROFITS
	gen pi_1603 = dRev_1603_mw - cost_mw*(1-`capital_subsidy') - fom_mw
	gen pi_ptc = dRev_PTC_mw - cost_mw - fom_mw
	
	*PUBLIC EXPENDITURE IN MILLION $ PER MW
	gen pubexp_1603 = cost_mw * `capital_subsidy'
	gen pubexp_ptc  = `output_subsidy' * (cf_1603 + `ptcresponse') * 730 * df_an_10 / 1e6 // convert dollars to millions of dollars
	
	*INCLUDE DEPRECIATION
	if(`include_depreciation'==1){
		local tax_rate = 0.35 // set marginal tax rate

		*GROSS DEPRECIATION
		*50% bonus in year 1, then 5-year MACRS halved bc of bonus: 10%, 16%, 9.6%, 5.76%, 5.76%, 2.88%
		*this is based on table A-1 of IRS Publication 946 (2012)
		
		gen deprec_factor = (0.5+0.1)*(1/(1+`rptc')) + 0.16*(1/(1+`rptc'))^2 + /// this is a multiplier to get PDV of depreciation per dollar of cost basis
			0.096*(1/(1+`rptc'))^3 + 0.0576*(1/(1+`rptc'))^4 + 0.0576*(1/(1+`rptc'))^5 + 0.0288*(1/(1+`rptc'))^6

		gen gross_deprec_PTC =  `tax_rate' * deprec_factor * cost_mw // add PDV of depreciation from profits, assuming marginal tax rate of 35%
		gen gross_deprec_1603 = `tax_rate' * deprec_factor * (1 - `capital_subsidy' / 2) * cost_mw  // add PDV of depreciation value after reducing cost basis by half of 1603 grant amount
		
		*DISCOUNT THE GOVERNMENT COST AT REGULAR DISCOUNT RATE 
		gen deprec_factor_gov = (0.5+0.1)*(1/(1+`rfirm')) + 0.16*(1/(1+`rfirm'))^2 + /// this is a multiplier to get PDV of depreciation per dollar of cost basis
			0.096*(1/(1+`rfirm'))^3 + 0.0576*(1/(1+`rfirm'))^4 + 0.0576*(1/(1+`rfirm'))^5 + 0.0288*(1/(1+`rfirm'))^6
	
		gen gross_deprec_PTC_gov =  `tax_rate' * deprec_factor_gov * cost_mw // add PDV of depreciation from profits, assuming marginal tax rate of 35%
		gen gross_deprec_1603_gov = `tax_rate' * deprec_factor_gov * (1 - `capital_subsidy' / 2) * cost_mw  // add PDV of depreciation value after reducing cost basis by half of 1603 grant amount
		
		
		replace pi_ptc = pi_ptc + gross_deprec_PTC 
		replace pi_1603 = pi_1603 + gross_deprec_1603
		*public expenditure per mw
		replace pubexp_ptc  = pubexp_ptc  + gross_deprec_PTC_gov
		replace pubexp_1603 = pubexp_1603 + gross_deprec_1603_gov
	}
	
	*CONVERT dQ PER MW to dQ IN LEVELS
	replace dQ_ptc = dQ_ptc * first_nameplate_capacity
	replace dQ_1603 = dQ_1603 * first_nameplate_capacity
	
	*CONVERT PUBLIC EXPENDITURE FROM MILLION $ PER MW TO $ IN LEVELS
	replace pubexp_ptc = pubexp_ptc * first_nameplate_capacity * 1e6
	replace pubexp_1603 = pubexp_1603 * first_nameplate_capacity * 1e6
	
	*SUBSIDY GROUP FOR 1603 PLANTS
	capture drop sgroup
	gen sgroup = "both" if pi_1603>=0 // & flag_1603==1
	replace sgroup = "1603 only" if pi_1603>=0 & pi_ptc<0 
	replace sgroup = "PTC only" if pi_1603<0 & pi_ptc>=0 
	replace sgroup = "neither" if pi_1603<0 & pi_ptc<0

	gen ind_pi_ptc = pi_ptc > 0
	gen ind_pi_1603 = pi_1603 > 0

	gen ptc_pref = cond(pi_ptc > pi_1603,1,0)

}
end

capture program drop tab_profits
program define tab_profits

	sum pi_*, detail
	
	di "Indicator for pi > 0 by type"
	tab ind_*
	
	di "1603 plants only" 
	tab ind_* if flag_1603 == 1
	
	di "PTC preference by subsidy type selected"
	tab ptc_pref flag_1603
end

