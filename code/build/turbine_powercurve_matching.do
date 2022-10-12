/*  This code takes every facility's wind speed and calculates an output
	based on the power curve
********************************************************************************/
clear
local fname turbine_powercurve_matching

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
use "$generated_data/eia_static.dta", clear
keep facilityid manufacturer_eia model_eia

* Merge in AWEA turbine information
merge 1:1 facilityid using "$generated_data/awea.dta", nogen keep(master matched) keepusing(awea_manufacturer awea_model)

rename (manufacturer_eia model_eia) (turbinemanufacturer turbinemodel)

* USE AWEA INFORMATION TO FILL IN EIA FACILITIES WITH MISSING TURBINE INFO
replace awea_manufacturer = subinstr(awea_manufacturer, "refurbished", "", 1)

replace turbinemanufacturer = awea_manufacturer if turbinemanufacturer == ""
replace turbinemodel        = awea_model        if turbinemodel == ""

* Fixing Vague EIA model if AWEA has specific model
replace turbinemodel = awea_model if inlist(turbinemodel, "mwt-1000", "1000a", "mwt 1000a", "mwt-1000a") & awea_model == "mwt62/1.0"
replace turbinemodel = awea_model if awea_model == "mwt62/1.0" & inlist(turbinemodel, "mitsubishi mwt-1000a", "mhi 1000-a")
replace turbinemodel = awea_model if awea_model == "mwt62/1.0" & turbinemodel == "mitsubishi mwt-1000a 1.0 mw"
replace turbinemodel = awea_model if awea_model == "1.6-82.5" & turbinemodel == "1.68" & turbinemanufacturer == "ge"

drop awea*
replace turbinemanufacturer = trim(turbinemanufacturer)

* STANDARDIZE MANUFACTURERS
replace turbinemodel = ""        if turbinemodel == "unknown"
replace turbinemanufacturer = "ge" if turbinemanufacturer == "ge energy"
replace turbinemanufacturer = "neg micon" if inlist(turbinemanufacturer, "micon")

* STANDARDIZE MODELS - ELIMINATE DUPLICATES MODELS IN THE DATA

* Get rid of Manufacturer names in model names
foreach model in enertech micon liberty mitsubishi nedwind suzlon vensys vestas zond {
	replace turbinemodel = subinstr(turbinemodel, "`model'", "", .)
}
replace turbinemodel = ltrim(turbinemodel)

*ZOND
replace turbinemodel = "z750" if inlist(turbinemodel, "750", "0.75") & turbinemanufacturer == "zond"

* Unison
replace turbinemodel = "u57" if turbinemodel == "u-57" & turbinemanufacturer == "unison"

* Vestas
replace turbinemodel = subinstr(turbinemodel, "-", "", 1) if turbinemanufacturer == "vestas" & ///
inlist(turbinemodel, "v-100", "v-15", "v-17", "v-27", "v-47", "v-80", "v-90", "v-82")

replace turbinemodel = "v47-660" if regexm(turbinemodel, "v47") & turbinemanufacturer == "vestas"

replace turbinemodel = "v82-1.65" if turbinemanufacturer == "vestas" & regexm(turbinemodel, "v82") & regexm(turbinemodel, "1.65")
replace turbinemodel = "v82-1.65" if turbinemodel == "v82-1650"

replace turbinemodel = "v90-1.8" if turbinemodel == "v90 mk 8"

replace turbinemodel = "v100-1.8" if inlist(turbinemodel, "v100 1.8", "v100 1.8 vcss")
replace turbinemodel = "v80-1.8" if turbinemodel == "1.8 mw v-80 mkiii"

replace turbinemodel = "v90-3.0" if turbinemanufacturer == "vestas" & ///
inlist(turbinemodel, ", v90/3mw", "v90 3.0 mw and 1.8 mw", "v90 3mw mk8", "v90 3mw", "v90 3.0")

replace turbinemodel = "v82" if turbinemodel == "vmn82"
replace turbinemodel = "v112-3.0" if turbinemodel == "v112 3.0"
replace turbinemodel = "v72" if turbinemodel == "72" & turbinemanufacturer == "vestas"
replace turbinemodel = "v17-90" if regexm(turbinemodel, "v17") & turbinemanufacturer == "vestas"

*Vensys
replace turbinemodel = "v77" if turbinemanufacturer == "vensys" & turbinemodel == "77"
replace turbinemodel = "v82" if turbinemanufacturer == "vensys" & turbinemodel == "82"


*Senvion. According to website only one mm92
replace turbinemodel = "mm92" if turbinemanufacturer == "senvion" & regexm(turbinemodel, "mm92")
replace turbinemodel = "mm92" if turbinemodel == "mm 92"

*Suzlon
replace turbinemodel = "s88-2100" if (regexm(turbinemodel, "s-88") | regexm(turbinemodel, "s88")) & regexm(turbinemodel, "2.1")
*No 905 for s64 so typo
replace turbinemodel = "s64-950" if inlist(turbinemodel, "s64 905kw", "s64 950 kw", "s64/950", "s64 950kw")
replace turbinemodel = "s64-1250" if turbinemodel == "s64 1.25mw"
replace turbinemodel = "s95-2100" if turbinemodel == "s95" //only one s95

*Siemens
replace turbinemodel = "swt-2.3-101" if turbinemanufacturer == "siemens" & ///
regexm(turbinemodel, "2.3") & regexm(turbinemodel, "101")

replace turbinemodel = "swt-2.3-93" if turbinemanufacturer == "siemens" & ///
regexm(turbinemodel, "2.3") & regexm(turbinemodel, "93")

replace turbinemodel = "swt-2.3-108" if turbinemanufacturer == "siemens" & ///
inlist(turbinemodel, "2-3-108", "2.3-108")

replace turbinemodel = "swt-3.0-101" if turbinemodel == "swt101.3" | turbinemodel == "swt 3.0-101"

replace turbinemodel = "swt-2.3-108" if turbinemodel == "swt 2.37-108"

*Nordex
replace turbinemodel = "n54/1000" if inlist(turbinemodel, "n-54", "1 mw", "1000","n1000", "n54/1000") & turbinemanufacturer == "nordex"
replace turbinemodel = "n100/2500" if inlist(turbinemodel, "n100")
replace turbinemodel = "n60/1300" if inlist(turbinemodel, "n-60", "n-60 1.3")

* Nordtank
replace turbinemodel = "ntk 65/13" if turbinemodel == "nkt 65"

*NEG MICON
replace turbinemodel = "nm52/900" if inlist(turbinemodel, "micon 900", "nm900-52", "nm52")
replace turbinemodel = "nm54/950" if turbinemodel == "nm54-950"
replace turbinemodel = "nm48/750" if inlist(turbinemodel, "mn48-750")
replace turbinemodel = "nm72/1500" if turbinemodel == "nm72-1.5"


*Mitsubishi
replace turbinemodel = "mwt-1000a" if turbinemanufacturer == "mitsubishi" & regexm(turbinemodel, "1000a")
replace turbinemodel = "mwt-1000a" if turbinemodel == "mhi 1000-a" | turbinemodel == "1000 a"
replace turbinemodel = "mwt-95/2.4" if regexm(turbinemodel, "mwt95") | regexm(turbinemodel, "mwt-95")
replace turbinemodel = "mwt-95/2.4" if turbinemodel == "mwt-2.4 95"
replace turbinemodel = "mwt-62/1.0" if turbinemodel == "mwt62/1.0"
replace turbinemodel = "mwt-62/1.0" if inlist(turbinemodel, "mwt 62/1.0")
replace turbinemodel = "mwt-102/2.4" if turbinemodel == "mwt102"
replace turbinemodel = "mwt-600-45" if turbinemodel == "mwt-600 (45m)"

*Goldwind
replace turbinemodel = "gw82/1500" if turbinemanufacturer == "goldwind" & regexm(turbinemodel, "82") & regexm(turbinemodel, "1500") 
replace turbinemodel = "gw82/1500" if inlist(turbinemodel, "gw82-1.5 mw", "gw82")
replace turbinemodel = "gw87/1500" if inlist(turbinemodel, "gw 87/1500", "gw87-1.5", "gw 87/1500")
replace turbinemodel = "gw100-2.5" if turbinemodel == "gw2.5pmdd100"
replace turbinemodel = "gw77/1500" if turbinemodel == "gw 77/1500"

* GE - MOST MODELS
replace turbinemodel = "1.6-100" if inlist(turbinemodel, "1.6 100/100", "1.6-100 wtg")
replace turbinemodel = "2.5 xl" if turbinemodel == "2.5xl+"
replace turbinemodel = "1.6-82.5" if inlist(turbinemodel, "1.6 82.5", "1.6mw 82.5")
replace turbinemodel = "1.6 ess" if inlist(turbinemodel, "1.6es", "1.6ess")
replace turbinemodel = "1.5 ess" if turbinemodel == "1.5 mw ess"
replace turbinemodel = "1.5 se" if turbinemodel == "1.5se"

* Looked up on GE 1.5-82.5 -> 1.5 xle, GE 1.6-82.5 -> 1.6 xle
replace turbinemodel = "1.5 xle" if turbinemodel == "1.5-82.5"
replace turbinemodel = "1.6 xle" if inlist(turbinemodel, "1.6 82.5", "1.6mw 82.5", "1.6-82.5")

* GAMESA
replace turbinemodel = "g52-850" if inlist(turbinemodel, "g52-0.8", "g5x-850kw")
replace turbinemodel = "g90-2.0" if inlist(turbinemodel, "g90-2.0mw", "g90-2mw")
replace turbinemodel = "g97-2.0" if inlist(turbinemodel, "g97-2.0 mw", "g97")
replace turbinemodel = "g87-2.0" if turbinemodel == "v87" & turbinemanufacturer == "gamesa"
replace turbinemodel = "g80-2.0" if turbinemodel == "g80"

* FUHRLANDER
replace turbinemodel = "fl 1500/77" if inlist(turbinemodel, "1500/77", "fl1577")

* EWT
replace turbinemodel = "dw54-900" if inlist(turbinemodel, "dw54", "awe54-900")

* CLIPPER
local clipper turbinemanufacturer == "clipper"
replace turbinemodel = "c93" if regexm(turbinemodel, "93") & `clipper'
replace turbinemodel = "c96" if regexm(turbinemodel, "96") & `clipper'

*BONUS
replace turbinemodel = "b65/13" if turbinemanufacturer == "bonus" & inlist(turbinemodel,"65/13", "65")

* ACCIONA
replace turbinemodel = "aw77-1500" if regexm(turbinemodel, "aw77/1500") | regexm(turbinemodel, "aw 77/1500")
replace turbinemodel = "aw125-3000" if turbinemodel == "aw125/3000"
replace turbinemodel = "aw82-1500" if regexm(turbinemodel, "aw82")
replace turbinemodel = "1.6-100" if turbinemodel == "1.6100ess" 

save "$generated_data/standardized_turbine_list.dta", replace

* CREATE STRING CROSS-WALK BETWEEN POWER CURVES AND OUR MODELS AND MANUFACTURERS
drop facilityid
duplicates drop

* CREATE ALL PAIR-WISE COMBINATIONS BY MANUFACTURER
joinby turbinemanufacturer using "$generated_data/power_curve.dta", unmatched(master)  _merge(pow)
keep turbinemanufacturer turbinemodel powercurve_turbinemodel source
duplicates drop
order turbinemanufacturer turbinemodel powercurve_turbinemodel source
/***************************************************************************************************
							               README 

The data-set above was manually examined and perfect matches between turbines in AWEA and EIA
and the powercurves datset were kept.

* IF THE POWERCURVES DATA OR THE EIA/AWEA DATA IS UPDATED THAT SHOULDN'T CHANGE THE DATA-SET
  BELOW. 
  
  The PERFECT MATCHES CAN BE USED AS A FILTER SO THAT IMPERFECT/NON-MATCHES CAN BE IMPROVED
  WITH NEW DATA
  
  nm 72, iec i
****************************************************************************************************/

* DATASET OF PERFECT MATCHES BETWEEN THE DATASETS
preserve
	clear
	input str50 turbinemanufacturer      str50 turbinemodel    str50 powercurve_turbinemodel
			"ewt"	              "dw54-900"	      "directwind 900/54"					
			"ge"	              "1.5 xle"	          "1.5xle"					
			"vestas"	          "v47-660"	          "v47/660"					
			"ge"	              "1.5 sle"	          "1.5sle"					
			"suzlon"	          "s64-1250"	      "s64/1250"					
			"dewind"	          "d8.2"	          "d8.2"								
			"fuhrlander"	      "fl 1500/77"	      "fl 1500/77"					
			"vestas"	          "v90-1.8"	          "v90/1800"					
			"neg micon"	          "nm48/750"	      "nm48/750"					
			"nordex"	          "n60/1300"	      "n60/1300"					
			"ge"	              "1.5 s"	          "1.5s"					
			"vestas"	          "v42-600"	          "v42/600"									
			"clipper"	          "c93"	              "c93"					
			"ge"	              "1.5-77"	          "1.5sle"					
			"vestas"	          "v44-600"	          "v44/600"					
			"mitsubishi"	      "mwt-1000"	      "mwt-1000"					
			"neg micon"	          "nm52/900"	      "nm52/900"					
			"neg micon"	          "nm72c/1500"	      "nm72c/1500"
			"neg micon"           "nm72/1500"         "nm 72, iec i"
			"vestas"	           "v80-1.8"	      "v80/1800"					
			"vestas"	           "v82-1.65"	      "v82/1650"					
			"mitsubishi"	       "mwt-1000a"	      "mwt-1000a"				
			"gamesa"	           "g52-850"	      "g52/850"					
			"suzlon"	           "s64-950"	      "s64/950"								
			"vestas"	           "v90-3.0"	      "v90/3000"					
			"gamesa"	           "g87-2.0"          "g87/2000"					
			"neg micon"	           "nm82/1650"	      "nm82/1650"							
			"siemens"	           "swt-2.3-93"	      "swt-2.3-93"					
			"suzlon"	           "s88-2100"	      "s88/2100"							
			"clipper"	           "c96"	          "c96"					
			"vestas"	           "v100-1.8"	      "v100/1800"					
			"mitsubishi"	        "mwt-95/2.4"	  "mwt-95-2.4"				
			"gamesa"	            "g90-2.0"	      "g90/2000"					
			"senvion"	            "mm92"	          "mm92"				
			"acciona"	            "aw77-1500"	       "aw 77-1500 class ii"					
			"siemens"	            "swt-2.3-82"	  "swt-2.3-82"								
			"mitsubishi"	        "mwt-62/1.0"	  "mwt-62-1000"				
			"mitsubishi"	        "mwt-92/2.4"	  "mwt-92-2.4"					
			"acciona"	            "aw82-1500"	      "aw 82-1500 class iiib"					
			"vestas"	            "v112-3.0"	      "v112/3000"					
			"siemens"	            "swt-2.3-101"	  "swt-2.3-101"					
			"clipper"	            "c89"	          "c89"					
			"gamesa"	            "g97-2.0"	      "g97/2000"					
			"aaer"	                "a-1500-70"	      "a-1500-70 70m 1500kw"					
			"goldwind"	            "gw77/1500"	       "gw77/1500"									
			"nordex"	            "n100/2500"	      "n100/2500"									
			"sany"	                "se8720iiie"	  "se8720iii"					
			"dewind"	            "d9.2"	          "d9.2"					
			"ge"	                "2.5 xl"	      "2.5xl"					
			"unison"	            "u57"	          "u57"					
			"mitsubishi"	        "mwt-102/2.4"	  "mwt-102-2.4"					
			"goldwind"	            "gw82/1500"	      "gw82/1500"					
			"sinovel"	            "sl1500/82"	      "sl 1500/82"								
			"vensys"	            "v82"	          "82"					
			"guodian"	            "gup1500-82"	  "up82"					
			"sany"	                "se9320iii-3"	  "se9320iii-3"					
			"leitwind"	            "ltw-77"	      "ltw77-1500"					
            "gamesa"                "g80-2.0"         "g80/2000"
			"vensys"	            "v77"	          "77"	
			"neg micon"             "nm54/950"        "nm54/950"
			"nordex"				"n90/2500"		  "n90/2500"	
			"vestas"                "v90-2.0"         "v90/2000"
			"vestas"                "v27-225"         "v27/225"
			"danwin"                "23/160"          "23/160"
			"ge"					"1.5 se"		  "1.5se"	
			"ge"                    "1.6-100"         "1.6-100"
			"ge"                    "1.6 xle"         "1.6-82.5"
			"ge"                    "1.7-100"         "1.7-100"
			"ge"                    "1.85-82.5"       "1.85-82.5"
			"ge"                    "1.85-87"         "1.85-87"
			"ge"                    "2.85-103"        "2.85-103"
			"goldwind"              "gw87/1500"       "gw87/1500"
			"siemens"               "swt-3.0-101"     "swt-3.0-101"
			"siemens"               "swt-3.2-113"     "swt-3.2-113"
			"vestas"                "v100-2.0"        "v100/2000"
			"vestas"                "v110-2.0"        "v110/2000"
			"vestas"                "v112-3.3"        "v112/3300"
			"nedwind"               "40"              "40/500"
			"goldwind"              "gw100-2.5"       "gw100/2500"
			"nordex"                "n54/1000"        "n54/1000"
			"suzlon"                "s97-2100"        "s97/2100"
			"suzlon"                "s95-2100"        "s95/2100"
			"bonus"                 "b62/1300"        "b62/1300"
			"gamesa"                "g114-2.0"        "g114/2000"
			"kenersys"              "k100 2.5"        "k100"
			"nordex"                "n117/2400"       "n117/2400"
			"nordtank"              "ntk 150/25"      "ntk150/25"
	end
	compress
	tempfile perfect_matches
	save "`perfect_matches'"
restore

compress
merge 1:1 turbinemanufacturer turbinemodel powercurve_turbinemodel using "`perfect_matches'", gen(non_perfect)
assert non_perfect != 2

* FILTER OUR PERFECT-MATCHES AND FOCUS ON NON-MATCHES
bys turbinemanufacturer turbinemodel: egen perfect_match = total(non_perfect == 3)
*Drop models that were perfectly matched
drop if perfect_match == 1
drop perfect_match
drop if turbinemanufacturer == "" 

* DATASET OF IMPERFECT MATCHES BETWEEN THE DATASETS
preserve
	clear
	input str50 turbinemanufacturer      str50 turbinemodel    str50 powercurve_turbinemodel	
					"ge"					"1.5 ess"			"1.5sle 77m 1.5mw"										
					"ge"					"1.6 sle"			"1.6-82.5"				
					"samsung"				"shi 2.5 mw"		"25s"						
					"siemens"				"swt-2.3-108"		"swt-2.3-101"										
					"sany"	                "se10020iiie-3"	    "se9320iii-3"
					"sany"                  "se11020"           "se9320iii-3"
					"ge"	                "1.6-103"	        "1.6-100"
					"bonus"                 "b65/13"            "b62/1300"
					"ge"                    "1.7-103"           "1.7-100"

	end
	compress
	tempfile imperfect_matches
	save "`imperfect_matches'"
restore

merge 1:1 turbinemanufacturer turbinemodel powercurve_turbinemodel using "`imperfect_matches'", gen(imperfect_matches)
assert imperfect_matches != 2

* FILTER OUT IMPERFECT MATCHES TO LOOK AT WHAT REMAINS
bys turbinemanufacturer turbinemodel: egen imperfect_match = total(imperfect_matches == 3)
*Drop models that were perfectly matched
drop if imperfect_match == 1
drop imperfect_match
drop if turbinemanufacturer == "" 

********************************************************************************
* 		CREATE CROSS-WALK BETWEEN TURBINE LIST AND POWERCURVE
********************************************************************************
use "$generated_data/standardized_turbine_list.dta", clear

gen flag_powercurve = 0

merge m:1 turbinemanufacturer turbinemodel using "`perfect_matches'"
assert _merge != 2
replace flag_powercurve = 2 if _merge == 3
drop _merge

/* powercurve_turbinemodel is now in the master dataset from previous merge. Need to use update
   and replace so that for missing values of this variable we use the using data-set
*/
merge m:1 turbinemanufacturer turbinemodel using "`imperfect_matches'", update replace
assert _merge != 2
replace flag_powercurve = 1 if _merge == 4
drop _merge

label define pcurve_match 0 "Unmatched" 1 "Imperfect Match" 2 "Matched"
label val flag_powercurve pcurve_match

* FOR UNMATCHED FACILITIES, GOING TO USE MODAL TURBINE IN CROSSWALK
local unmatched flag_powercurve == 0
qui replace turbinemanufacturer = "ge" if `unmatched'
qui replace powercurve_turbinemodel = "1.5sle" if `unmatched'

* BRING IN POWERCURVE INFORMATION
merge m:1 turbinemanufacturer powercurve_turbinemodel using "$generated_data/power_curve.dta", keep(matched master) nogen
keep facilityid turbinemanufacturer flag_powercurve powercurve_turbinemodel powercurve_max_cap w*
compress
save "$generated_data/models_powercurve_xwalk.dta", replace
*********************************************************************************
tempsetup
capture log close
exit
