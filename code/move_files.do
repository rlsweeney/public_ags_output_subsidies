/* RUN ALL OF THE BUILD DO FILES */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************

foreach tf in final_panel_static final_panel_dynamic statescoord statesdb ///
				pjm_negative_lmp caiso_negative_lmp ercot_negative_lmp  ///
				miso_negative_lmp neiso_negative_lmp nyiso_negative_lmp ///
				lmp_hour_of_day_fractions lmp_nodes_with_lat_long  moerdata {
				
	copy "$dropbox/generated_data/`tf'.dta" "$repodir/generated_data/`tf'.dta", replace
}
