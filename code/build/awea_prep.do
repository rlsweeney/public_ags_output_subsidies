/* Prepare variables from AWEA that will be used in the final Panel */
clear
local fname awea_prep

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text

global generated_data "$dropbox\ags_capital_vs_output\generated_data"

********************************************************************************
global awea_data "$dropbox\Data\proprietary\awea"
********************************************************************************
*			PROGRAMS TO FACILITATE AWEA-EIA MATCHING
********************************************************************************


/* FUNCTION 1: For large plants, AWEA lists it only once 
			   whereas EIA gives an ID to the sub-plants within the large plant
	 
	 Example:
	 Say we know AWEA Observation with ID 1 maps to 2, 3 in EIA
	 Then:
	
	 Before:                           After: 
	 ID      Turbine                   ID            Turbine
	 1       "Vestas"                  1             "Vestas"
	                                   2             "Vestas"
	                                   3             "Vestas"
The matching information was put together by RA Jeff Bryant        */
capture program drop awea_to_eia_match 
program define awea_to_eia_match 
	/* First part of the program is we bring in the match information using join-by. Forms
	   all pair-wise combinations to expand the data. The data includes matching an ID
	   to itself so we don't lose any observations */
	   joinby facilityid using "$generated_data/awea_eia_handmatch.dta", unmatched(master)
	   replace facilityid = sub_facilityid if _merge == 3
	   drop _merge sub_facilityid
	   
	   /* For these two AWEA datasets(turbines and projects), Jeff indicates that ID 56840 of
	      the Marshall wind farm is the matching ID, but that ID is not in the AWEA data. 58826
		  is the ID in the AWEA data that will be expanded to all other marshall wind EIA ID's
		  
		  Code below creates 4 observation for each one of the 4 other EIA facility ID's in the
		  Marshall wind farm
	   */
	   foreach fid in 56840 56824 56825 56827 56828{
			expand 2 if facilityid == 56826, gen(dup)	 
			replace facilityid = `fid' if dup == 1
			drop dup	
		}
end

* FUNCTION 2 - FILL IN OBS WITHOUT EIA FACILITY ID'S 
capture program drop fill_id
program define fill_id
	
	*FOUND BY JEFF BRYANT
	replace facilityid = 7769  if eiaplantname == "Lalamilo Windfarm" & state == "HI"
	replace facilityid = 50826 if eiaplantname == "Tres Vaqueros Wind Farms LLC" & state == "CA"
	replace facilityid = 50532 if eiaplantname == "Victory Garden Phase IV LLC" & state == "CA"
	replace facilityid = 54684 if eiaplantname == "Difwind Farms Ltd VI" & state == "CA"
	replace facilityid = 58038 if projectphase == "Little Cedar" & state == "IA"
	
	* ADDITIONAL MATCHES BY BLAKE BARR
	replace facilityid = 59637 if projectphase == "Adams"        & state == "IA"
	replace facilityid = 59734 if projectphase == "Briscoe"      & state == "TX"
	replace facilityid = 59975 if projectphase == "Carousel"     & state == "CO"
	replace facilityid = 54684 if projectphase == "Difwind 4"    & state == "CA"
	replace facilityid = 60049 if projectphase == "Golden Hills" & state == "CA"

	replace facilityid = 59732 if  projectphase == "Green Pastures I" &  state == "TX"
	replace facilityid = 59733 if  projectphase == "Green Pastures II" & state == "TX"

	replace facilityid = 59442 if projectphase == "Logan's Gap Wind" & state == "TX"

	replace facilityid = 60059 if projectphase == "Los Vientos V" & state == "TX"
	replace facilityid = 59435 if projectphase == "Oak Tree"      & state == "SD"
	replace facilityid = 59475 if projectphase == "Palo Duro"     & state == "TX"

	replace facilityid =  60262 if projectphase == "Prairie Breeze II"   & state == "NE"
	replace facilityid =  59943 if projectphase == "Rattlesnake"         & state == "TX"
	replace facilityid =  59654 if projectphase == "Sendero"             & state == "TX"
	replace facilityid =  59034 if projectphase == "Shannon"             & state == "TX"
	replace facilityid =  60128 if projectphase == "Zephyr Wind Project" & state == "OH"
	
	replace facilityid = 58958 if projectphase == "Camelot Wind Project" & state == "MA"
	replace facilityid = 59118 if projectphase == "Cameron"              & state == "TX"
	replace facilityid = 59655 if projectphase == "Campbell County"      & state == "SD"
	replace facilityid = 60069 if projectphase == "Cedar Bluff"          & state == "KS"
	replace facilityid = 59147 if projectphase == "Fairwind"             & state == "MD"
	replace facilityid = 59725 if projectphase == "Fairhaven Wind"       & state == "MA"
	replace facilityid = 59328 if projectphase == "Golden Acorn Casino"  & state == "CA"
	replace facilityid = 59974 if projectphase == "Golden West Wind Farm" & state == "CO"
	replace facilityid = 59776 if projectphase == "Heartland Community College" & state == "IL"
	replace facilityid = 60104 if projectphase == "Javelina" & state == "TX"
	replace facilityid = 59460 if projectphase == "Kay Wind" & state == "OK"
	replace facilityid = 59022 if projectphase == "Kingston" & state == "MA"
	replace facilityid = 59735 if projectphase == "Kirkwood Community College" & state == "IA"
	replace facilityid = 59837 if projectphase == "Slate Creek" & state == "KS"
	replace facilityid = 58995 if projectphase == "St. Olaf Wind Project" & state == "MN"
	replace facilityid = 58927 if projectphase == "Story City Wind Project" & state == "IA"
	replace facilityid = 59621 if projectphase == "Jumbo Road" & state == "TX"
	replace facilityid = 58932 if projectphase == "Traer Wind Project" & state == "IA"
	replace facilityid = 59736 if projectphase == "Valentine" & state == "NE"
	replace facilityid = 59724 if projectphase == "Scituate Wind" & state == "MA"
	
	replace facilityid = 50821 if projectphase == "Mojave 16"
	replace facilityid = 50822 if projectphase == "Mojave 17"
	replace facilityid = 50823 if projectphase == "Mojave 18"
	
	
end

/* ADDITIONAL MATCHES FOUND BY: CP, TG, and RS. 
	This data-set will be used below to
    link and expand AWEA ID's into multiple ID's in EIA
*/
input facilityid    sub_facilityid
	   54298          54298                  
	   54298          54297                 
	   54298          54299                 
	   54298          54300                 
	   55719          55719                  
	   55719          55720                  
	   55560          55560                 
	   55560          55989                  
	   56201          56201                
	   56201          56202                  
	   56201          56204                 
	   56201          56205                  
	   56216          56216                  
	   56216          56218                 
	   56275          56275                  
	   56275          52165                  
	   56275          56276                  
	   56413          56413                  
	   56413          56409                 
	   56413          56410                  
	   56413          56411                 
	   56413          56412                
	   59331          59331                  
	   59331          57791                 
	   57098          57098                
	   57098          57922
	   58465          58465                 
	   58465          58464                 
	   58940          58940                 
	   58940          58939                  
end
tempfile additional_matches
save "`additional_matches'"

********************************************************************************
* 								TURBINE DATA
********************************************************************************

* We are only interested in AWEA turbine data 
* for those EIA facilities that do not have a turbine
use "$generated_data/eia_static.dta", clear
keep if manufacturer_eia == "" & model_eia == ""
keep facilityid
tempfile eia_without_turbines
save "`eia_without_turbines'"

* BRING IN AWEA TURBINE DATA
import delimited using "$awea_data/turbines.csv", clear
ren eiaplantid facilityid

* MATCH a couple AWEA facilities TO EIA
fill_id
replace turbinemodel = "S88" if facilityid == 57248 

*CONSTRUCT FOOTPRINT 
egen awea_long_max =  max(turbinelongitude), by(facilityid)
egen awea_long_min =  min(turbinelongitude), by(facilityid)

egen awea_lat_max =  max(turbinelatitude), by(facilityid)
egen awea_lat_min =  min(turbinelatitude), by(facilityid)

egen awea_geo_turbines = count(turbinelatitude), by(facilityid)
egen awea_geo_MW = sum(turbinecapacitymw), by(facilityid)

geodist awea_lat_max awea_long_max awea_lat_max awea_long_min , generate(xdist) miles
geodist awea_lat_max awea_long_max awea_lat_min awea_long_max, generate(ydist) miles

gen awea_area = xdist*ydist

merge m:1 facilityid using "`eia_without_turbines'", keep(master matched)


* THIS FACILITTY NEEDED TO BE CHANGED NO MODE - GOOGLED SEARCHED
replace turbinemanufacturer = "vestas" if facilityid == 7769
replace turbinemodel = "v47-660"       if facilityid == 7769

/* The following loop generated manufacturer and model mode. It then checks to make sure
   of turbines with no data in eia (we will need the awea data) 
   the modes are not missing
*/
foreach t in manufacturer model {
	bys facilityid: egen awea_`t' = mode(turbine`t')
	replace awea_`t' = lower(awea_`t')
	qui count if awea_`t' == "" & _merge == 3
	assert `r(N)' == 0
}

bys facilityid: gen tn = _n
keep if tn == 1
drop tn

keep facilityid awea_manufacturer awea_model awea_geo_turbines awea_geo_MW awea_area

* Fill in exact AWEA to EIA matches using program above
awea_to_eia_match

* Bring in additional matches (in dataset above)
joinby facilityid using "`additional_matches'", unmatched(master)
replace facilityid = sub_facilityid if _merge == 3
drop _merge sub_facilityid

compress
sort facilityid 
tempfile awea_turbines
save "`awea_turbines'"
********************************************************************************
* 							AWEA PPA DATA
********************************************************************************
import delimited using "$awea_data\projects.csv", clear
ren eiaplantid facilityid
order facilityid

keep facilityid powerpurchasertype pparate ppastartyear ppaendyear ///
     mwcontracted offtaketype eiaplantname state projectphase ///
	 powerpurchasertypedetails powerpurchaser ppaduration

* DEAL WITH OBSERVATIONS THAT HAVE MULTIPLE ID'S SEPERATED BY COMMA
gen flag_awea = regexm(facilityid, ",")

* GOING TO SPLIT INTO SEPERATE VARIABLES AND THEN RESHAPE
preserve
	keep if flag_awea == 1 
	split facilityid, parse(",")
	gen n = _n //for the reshape
	drop facilityid
	reshape long facilityid, i(n) j(fid)
	destring facilityid, replace
	drop if facilityid == .
	drop n fid
	replace flag_awea = 2
	tempfile expansion
	save "`expansion'", replace
restore

drop if flag == 1
destring facilityid, replace

append using "`expansion'"

* Green Pastures needs to be split
local both_green projectphase == "Green Pastures I, Green Pastures II"
expand 2 if `both_green'
bys projectphase: replace projectphase = "Green Pastures I" if _n == 1 & `both_green'
replace projectphase = "Green Pastures II" if `both_green'

* Mojave 16/17/18 needs to be split
local three_mojave projectphase == "Mojave 16/17/18"
expand 3 if `three_mojave'
bys projectphase: replace projectphase = "Mojave 16" if `three_mojave' & _n == 1
bys projectphase: replace projectphase = "Mojave 17" if `three_mojave' & _n == 1
replace projectphase = "Mojave 18" if `three_mojave' 

* INCORPORATE FACILITY ID MATCHES FOUND MANUALLY BY JEFF BRYANT 
fill_id

drop eiaplantname projectphase state flag
duplicates drop

* Bring in exact AWEA - EIA matches using program
awea_to_eia_match

* Bring in additional matches (in dataset above)
joinby facilityid using "`additional_matches'", unmatched(master)
replace facilityid = sub_facilityid if _merge == 3
drop _merge sub_facilityid

drop if facilityid == . 
sort facilityid, stable 
collapse (firstnm) *ppa* offtaketype mwcontracted ///
				   powerpurchaser powerpurchasertype powerpurchasertypedetails, by(facilityid)
				
* COMBINE TURBINE AND PPA
merge 1:1 facilityid using "`awea_turbines'", keep(matched master) nogen

compress
sort facilityid
save "$generated_data/awea.dta", replace
********************************************************************************
tempsetup
capture log close
exit

