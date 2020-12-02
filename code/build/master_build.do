/* RUN ALL OF THE BUILD DO FILES */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************

global build_code "$repodir/code/build"

* RUN EXTERNALLY
* THESE FILES REQUIRE the external hard drive where the wind data is stored
*do "$build_code/wind_prep.do" // this requires the external hard drive where the wind data is stored
*do "$build_code/calc_ouput.do" // this requires the external hard drive where the wind data is stored
* the files created are `windspeed.dta`, `calculated_output.dta`, which has been saved to the generated_data folder

**********************************************
/* NEGATIVE PRICE DATA */
*do "$build_code/negative_lmp_nodes.do" // this takes a long time

*do "$build_code/negative_lmp_hourofday.do" // this less time but a lot of memory

*do "$build_code/match_nodes_to_lat_long.do" 

***********************************************
/* Scripts to Build Final Panel */
do "$build_code/eia_prep.do"

do "$build_code/awea_eia_handmatch.do"

do "$build_code/awea_prep.do"

do "$build_code/prep_power_curve.do"

do "$build_code/turbine_powercurve_matching.do"

do "$build_code/treasury_1603_prep.do"

do "$build_code/snl_prep.do"

do "$build_code/rec_prep.do"

do "$build_code/out_of_state_rec.do"

do "$build_code/build_final_panel.do"

do "$build_code/import_deflators.do"

do "$build_code/clean_bnef_cost_data.do"
**************************************************
