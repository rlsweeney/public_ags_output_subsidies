/* GEOLOCATE ISO NODES
********************************************************************************/
local fname match_nodes_to_lat_long

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global output "$repodir/generated_data"

*******************************
* BRING IN SNL LAT/LONG DATA
*******************************
import excel "$dropbox\Data\proprietary\snl\LMP lat longs.xlsx", firstrow clear
renvars, lower
rename (lmpkey lmpname isoname) (node_id node_name iso)
drop isokey node_id

replace iso = "CAISO" if regexm(iso, "California Independent")
replace iso = "PJM"   if regexm(iso, "PJM")
replace iso = "NEISO" if iso == "ISO New England"
replace iso = "MISO"  if iso == "Midcontinent Independent System Operator"
replace iso = "ERCOT" if iso == "Electric Reliability Council of Texas"
replace iso = "NYISO" if iso == "New York Independent System Operator"
keep if inlist(iso, "CAISO", "PJM", "NEISO", "MISO", "ERCOT", "NYISO")

replace latitude = "" if latitude == "NULL"
replace longitude = "" if longitude == "NULL"
destring latitude longitude, replace
compress
save "snl_nodes_latlong.dta", replace


********************************
* MERGE NODE DATA WITH LAT LONG
********************************

/* EVENTUALLY FOR ALL BUT PJM, JUST START WITH THE ALL ISO'S DATASET */

* NYISO
use "$output/nyiso_negative_lmp.dta", clear
keep node_name iso type
duplicates drop
merge 1:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "NYISO"
tempfile nyiso_matches
save "`nyiso_matches'"


* ERCOT
use "$output/ercot_negative_lmp.dta", clear
keep node_name iso
duplicates drop
merge 1:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "ERCOT"
tempfile ercot_matches
save "`ercot_matches'"

* MISO
use "$output/miso_negative_lmp.dta", clear
replace node_name = trim(node_name)
keep node_name iso type
duplicates drop
drop if node_name == "NSP.BAT.SER" & type == "" // gennode only filled in for some years. Verified in the data
merge 1:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "MISO"
tempfile miso_matches
save "`miso_matches'"

* NEISO
use "$output/neiso_negative_lmp.dta", clear
replace node_name = trim(node_name)
keep node_name iso type
duplicates drop
merge 1:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "NEISO"
tempfile neiso_matches
save "`neiso_matches'"

*CAISO
* First prepare Node Type crosswalk
local xsheet "$dropbox\Data\public\ISO_LMP\CAISO\FullNetworkModel_NodeMapping.xls"
import excel "`xsheet'", sheet("GEN_RES") firstrow clear
keep PNODEAPNODEID COMMENTS
gen ag_gen_node = cond(regexm(COMMENTS, "Aggregated Pnode"), 1, 0)
drop COMMENTS
rename PNODEAPNODEID node_name
duplicates drop
tempfile gen_nodes
save "`gen_nodes'"


use "$output/caiso_negative_lmp.dta", clear 

* BRING IN NODE TYPE
merge m:1 node_name using "`gen_nodes'", keep(master matched) 
gen gen_node = cond(_merge == 3, 1, 0)
drop  _merge
replace ag_gen_node = 1 if ag_gen_node == .

keep node_name iso gen_node ag_gen_node
duplicates drop
merge 1:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "CAISO"
tempfile caiso_matches
save "`caiso_matches'"


* To save memory, I kept PJM ID data in a seperate file
use "$dropbox/Data/public/ISO_LMP/PJM/pjm_node_id_info.dta", clear
gen iso = "PJM"
sort node_id
rename node_name node_name_only
gen node_name = node_name_only + " " + equipment + " " + voltage

merge m:1 node_name iso using "snl_nodes_latlong.dta"
drop if iso != "PJM"

*PJM MONTHLY DATA DOES NOT HAVE THE LONG NAME SO NEED TO KEEP THIS
rename node_name node_name_long
rename node_name_only node_name
keep node_id node_name* type iso state latitude longitude _merge zone
tempfile pjm_matches
save "`pjm_matches'"


* Bring them all together
clear
foreach iso in nyiso ercot miso neiso pjm caiso {
	append using "``iso'_matches'"
}

* Generate a Variable
rename _merge node_in_data
label define node 1 "Only in LMP Data" 2 "Only in Lat/Long Data" 3 "In both Lat/Long and LMP data"
label values node_in_data node
compress
order node_id node_name
save "$output/lmp_nodes_with_lat_long.dta", replace

********************************************************************************
tempsetup
capture log close
exit
