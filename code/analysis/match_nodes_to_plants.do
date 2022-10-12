/* MATCH NEGATIVE NODAL PRICE DATA
- PART 1: finds the closest nodes to each plant 
- PART 2: creates a smaller hourly lmp data set just for the nodes close to 
	wind farms, for use in `get_negative_price_production.do'

********************************************************************************/
local fname match_nodes_to_plants
capture log close

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup


log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

/*******************************************************************************
PART 1: 
*******************************************************************************/
*BRING IN NODE DATA AND DEFINE SAMPLE
*from build/negative_lmp_nodes.do

clear
foreach iso in ercot miso neiso nyiso pjm caiso {
	append using "$generated_data/`iso'_negative_lmp.dta"
}
compress
save all_iso_negative_lmp, replace

use all_iso_negative_lmp, clear
tostring node_id, gen(my_node_id)
replace my_node_id = node_name if iso != "PJM"
replace my_node_id = subinstr(my_node_id," ","",.)
gen my_node_string = iso + "-" + my_node_id
sort my_node_string year month
by my_node_string: gen nodeObs = _N
by my_node_string: gen node_n = _n

keep if node_n == 1
keep my_node* node_name node_id iso nodeObs
save nodecounts, replace



* GET NODE TYPE INFO AND LAT LONG DATA FROM SNL
*from build/match_nodes_to_lat_long.do
use "$generated_data/lmp_nodes_with_lat_long.dta", clear
drop if node_in_data == 2 // drop locations not found in LMP data

tostring node_id, gen(my_node_id)
replace my_node_id = node_name if iso != "PJM"
replace my_node_id = subinstr(my_node_id," ","",.)
gen my_node_string = iso + "-" + my_node_id

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

drop if node_id == 112585983  // dupe in pjm 
drop if node_id == 65732121
*drop two duplicates with leading zeros
sort my_node_id node_name
by my_node_id: gen te = _n
drop if te > 1

rename state node_state
keep node_id node_name iso node_lat node_long my_node* flag_* node_state

merge 1:1 my_node_id using nodecounts, keep(match) nogen

save lmp_geonode_list, replace


/*******************************************************************************
MATCH WIND FARMS TO NEAREST NODE IN ISO DATA
*******************************************************************************/
* BRING IN WIND FARM LOCATIONS 
use "$generated_data/final_panel_static.dta", clear

rename a1603 flag_1603
replace flag_1603 = 0 if flag_1603 == .
label var flag_1603 "1603 Grant" 

rename state plant_state

*CLEAN ISO NAMES
gen iso_rto_code = cond(iso_snl!= "",iso_snl,isortocode)

replace iso_rto_code = "NEISO" if iso_rto_code == "New England"
replace iso_rto_code = "NYISO" if iso_rto_code == "New York"
replace iso_rto_code = "MISO" if iso_rto_code == "MISO, SPP"
replace iso_rto_code = "PJM" if iso_rto_code == "MISO, PJM" 
replace iso_rto_code = "ERCOT" if iso_rto_code == "ERCOT, SPP" 
replace iso_rto_code = "None" if iso_rto_code == ""
rename iso_rto_code plant_iso

keep facilityid eia_lat eia_long ope_date_min plant_iso flag_1603 plant_state
save plantdata, replace

*FIRST FIND NEAREST NODE TO EACH PLANT
use lmp_geonode_list, clear
keep if nodeObs == 48
keep if flag_in_geodata
rename iso my_node_iso
keep my_node_id my_node_string node_lat node_long my_node_iso node_name node_id
save nodedata, replace

use plantdata, clear
geonear facilityid eia_lat eia_long using nodedata, ///
	n(my_node_string node_lat node_long) long ///
	near(20)
sort facilityid km
save mlist, replace

use mlist, clear
merge m:1 facilityid using plantdata, nogen keep(match)
merge m:1 my_node_string using nodedata, nogen keep(match)
gen iso_match = cond(my_node_iso == plant_iso,1,0)
save plant_lmp_matches_n20, replace 

use plant_lmp_matches_n20, clear
keep if iso_match	
gsort facilityid km 
by facilityid: gen nn = _n
keep if nn == 1
keep facilityid my_node_string km_to_my_node
merge m:1 my_node_string using nodedata, nogen keep(match)
*rename my_node_string node_string_inISO 
*rename km_to_my_node km_ISOnode
save "$generated_data/facility_closestnode_ISO.dta", replace


use plant_lmp_matches_n20, clear
gsort facilityid km 
by facilityid: gen nn = _n
keep if nn == 1
keep facilityid my_node_string km_to_my_node
merge m:1 my_node_string using nodedata, nogen keep(match)
*rename my_node_string node_string_nearest
*rename km_to_my_node km_ClosestNode
save "$generated_data/facility_closestnode.dta", replace


/*******************************************************************************
PART 2: 
*******************************************************************************/

use "$generated_data/facility_closestnode.dta", clear
append using "$generated_data/facility_closestnode_ISO.dta"
bys my_node_string: gen tn = _n
keep if tn == 1
drop tn
save uniquenodes, replace

** MISO 
use uniquenodes, clear
keep if my_node_is == "MISO"
di _N
save isonodes, replace

use isonodes, clear
keep node_name
merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/MISO/miso_2009.dta", nogen keep(match master)
save apdat, replace 

forval i = 2010/2015 {
	use isonodes, clear
	keep node_name
	merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/MISO/miso_`i'.dta", nogen keep(match master)
	append using apdat
	save apdat, replace 
}

save miso_plant_nodes, replace


** CAISO 
use uniquenodes, clear
keep if my_node_is == "CAISO"
di _N
save isonodes, replace

use isonodes, clear
keep node_name
merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/CAISO/caiso2009.dta", nogen keep(match master)
save apdat, replace 

forval i = 2010/2015 {
	use isonodes, clear
	keep node_name
	merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/CAISO/caiso`i'.dta", nogen keep(match master)
	append using apdat
	save apdat, replace 
}

save caiso_plant_nodes, replace



** ERCOT 
use uniquenodes, clear
keep if my_node_is == "ERCOT"
di _N
save isonodes, replace

use isonodes, clear
keep node_name
merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/ERCOT/ercot_2010.dta", nogen keep(match master)
save apdat, replace 

forval i = 2011/2015 {
	use isonodes, clear
	keep node_name
	merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/ERCOT/ercot_`i'.dta", nogen keep(match master)
	append using apdat
	save apdat, replace 
}

save ercot_plant_nodes, replace


** PJM
use uniquenodes, clear
keep if my_node_is == "PJM"
di _N
keep node_name node_id
save isonodes, replace

use "$dropbox/Data/public/ISO_LMP/PJM/pjm_2009.dta", clear
sort node_name node_id date hour lmp
bys node_name node_id date hour: gen tn = _n
keep if tn == 1
drop tn 
merge m:1 node_name node_id using isonodes, nogen keep(match)
save apdat, replace 


forval i = 2010/2015 {
	use "$dropbox/Data/public/ISO_LMP/PJM/pjm_`i'.dta", clear
	sort node_name node_id date hour lmp
	bys node_name node_id date hour: gen tn = _n
	keep if tn == 1
	drop tn 
	merge m:1 node_name node_id using isonodes, nogen keep(match)
	append using apdat
	save apdat, replace 
}

save pjm_plant_nodes, replace


** NEISO 
use uniquenodes, clear
keep if my_node_is == "NEISO"
di _N
replace node_name = strtrim(node_name)
keep node_name
save isonodes, replace

use "$dropbox/Data/public/ISO_LMP/NEISO/neiso_lmp_2009.dta", clear
replace node_name = strtrim(node_name)
merge m:1 node_name using isonodes, nogen keep(match using)
save apdat, replace 

forval i = 2010/2015 {
	use "$dropbox/Data/public/ISO_LMP/NEISO/neiso_lmp_`i'.dta", clear
	replace node_name = strtrim(node_name)
	merge m:1 node_name using isonodes, nogen keep(match using)
	append using apdat
	save apdat, replace 
}

save neiso_plant_nodes, replace


** NYISO
use uniquenodes, clear
keep if my_node_is == "NYISO"
di _N
save isonodes, replace

use isonodes, clear
keep node_name
merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/NYISO/nyiso_2009.dta", nogen keep(match master)
save apdat, replace 

forval i = 2010/2015 {
	use isonodes, clear
	keep node_name
	merge 1:m node_name using "$dropbox/Data/public/ISO_LMP/NYISO/nyiso_`i'.dta", nogen keep(match master)
	append using apdat
	save apdat, replace 
}

save nyiso_plant_nodes, replace


** append all together 
use pjm_plant_nodes, clear
gen ISO = "PJM"
di _N
save apdat, replace

local isolist caiso ercot miso neiso nyiso 
foreach tn in `isolist' {
	di "`tn'"
	use `tn'_plant_nodes, clear
	gen ISO = strupper("`tn'")
	di _N
	append using apdat
	save apdat, replace

}

gen Year = year(date)
gen Month = month(date)

save "$dropbox/Data/public/ISO_LMP/closenodes_hourly_data.dta", replace

********************************************************************************
tempsetup
cd "$repodir" 
capture log close
exit
