/*There are facility ID's that are treated as one by AWEA and seperate by EIA. 
  This do-file pulls in those and creates a cross-walk between them
********************************************************************************/
clear
local fname awea_eia_handmatch

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
import excel "$dropbox\Data\proprietary\awea\eia_awea_handmatches.xlsx", sheet("Sheet1") firstrow clear
renvars, lower

*The matched ID needs to be mapped to every other ID in the group (name)
bys name: gen primary_fid = facilityid if eiaaweamatch == "matched"
order primary_fid
sort name eiaaweamatch
carryforward primary_fid, replace

keep primary_fid facilityid

*Now I have a list of facilities in AWEA mapped to the right facility in EIA
rename facilityid sub_facilityid
rename primary_fid facilityid
sort facilityid sub_facilityid
save "$generated_data/awea_eia_handmatch.dta", replace
********************************************************************************
tempsetup
capture log close
exit
