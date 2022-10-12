/* Clean EIA 860, 923, and 826 data */
local fname eia_prep

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global eia     "$dropbox/Data/public/eia"
global eia860  "$eia/eia_860"
global eia923  "$eia/eia_923"
********************************************************************************
* PROGRAM TO STANDARDIZE ID VARS ACROSS ALL FILES
capture program drop standardize_id_variables
program define standardize_id_variables

	qui {
		renvars, lower
		renvars, subs("_" "")

		capture rename utilcode    operatorid
		capture rename utilityid   operatorid
		capture rename utilityname operatorname
		capture rename utilname    operatorname

		capture rename plntcode  facilityid
		capture rename plantid   facilityid
		capture rename plantcode facilityid
		capture rename plntname  facilityname
		capture rename plantname facilityname

		capture rename gencode     genid
		capture rename generatorid genid
	}
end

/*Going to do a lot of excel importing all with first row and clear options
* PARAMETERS: 
	1. file_string - string that contains location of the file
	2. list of excel options 
*/
capture program drop import_ex
program define import_ex
	args file_string excel_options
	import excel "`file_string'", `excel_options' firstrow clear
end

********************************************************************************
*								EIA 860 DATA
********************************************************************************

**********************
* FACILITY LEVEL DATA
**********************
forval y = 2002 / 2015 {
	qui cd "$eia860/eia860`y'"
	*****IMPORT DATA - DIFF YEARS, DIFF FILE FORMATS *******
	local twodigit = substr("`y'", 3, .)
	if inrange(`y', 2002, 2003) import delimited using "PLANTY`twodigit'", clear
	else {
		local start_2nd_row cellrange(A2)
		if inrange(`y', 2004, 2009)      import_ex  "PlantY`twodigit'.xls"
		else if `y' == 2010              import_ex  "PlantY`y'.xls"
		else if inrange(`y', 2011, 2012) import_ex  "PlantY`y'.xlsx"      `start_2nd_row'
		else                             import_ex  "2___Plant_Y`y'.xlsx" `start_2nd_row'
	}
	qui {
		standardize_id_variables
		
		capture rename plntzip zip
		capture rename zip5 zip
		capture rename plntstate state
		capture rename nerc nercregion
		capture rename balancingauthoritycode balancingauthority
		capture rename sector sector_number
		capture rename sectornumber sector_number
		capture destring sector_number, replace
		capture rename sectorname sector_name
		capture rename regulatorystatus regulatory_status
		
		destring zip, replace
		gen year = `y'
		local keepvars operatorid facilityid facilityname state zip nercregion year 
		* Regulatory Status (2006-) ISO/RTO Var (2010 - 2012). Balancing Authority (2013-2015)
		* Sector number nad name (2009 - 
		if `y' >= 2006              local keepvars `keepvars' regulatory_status
		if `y' >= 2009              local keepvars `keepvars' sector_name sector_number
		if inrange(`y', 2010, 2012) local keepvars `keepvars' isortocode isorto
		else if `y' >= 2013         local keepvars `keepvars' balancingauthority  latitude longitude
		keep `keepvars'
		
		tempfile plant`y'
		save "`plant`y''"
	}
}
clear 
forval y = 2002 / 2015 {
	append using "`plant`y''"
}
destring latitude longitude, replace
*TAKE MOST RECENT FACILITY NAME AND FILL IN FOR ALL YEARS
duplicates drop
bys facilityid (year): gen fac_name = facilityname[_N]
drop facilityname
rename fac_name facilityname

* Create numeric variable for whether in ISO
gen in_iso_rto = .
replace in_iso_rto = 1 if isorto == "Y"
replace in_iso_rto = 0 if isorto == "N"
drop isorto
compress
save "$repodir/temp/eia_plant_data", replace

**************************
* UTILITY/OPERATOR DATA
**************************
forval y = 2002 / 2015 {
	qui cd "$eia860/eia860`y'"
	*****IMPORT DATA - DIFF YEARS, DIFF FILE FORMATS *******
	local twodigit = substr("`y'", 3, .)
	if inrange(`y', 2002, 2003)      import delimited using "UTILY`twodigit'", clear
	
	else {
		local st_two cellrange(A2)
		if inrange(`y', 2004, 2008)      import_ex "UtilY`twodigit'.xls"
		else if `y' == 2009              import_ex "UtilityY`twodigit'.xls"
		else if `y' == 2010              import_ex "UtilityY`y'.xls"
		else if inrange(`y', 2011, 2012) import_ex "UtilityY`y'.xlsx" `st_two'
		else                             import_ex "1___Utility_Y`y'.xlsx" `st_two'
	}
	qui {
		standardize_id_variables
		capture rename entitytype entity_type
		gen year = `y'
		if `y' >= 2013 keep operatorname operatorid year entity_type
		else keep operatorname operatorid year
		drop if operatorid == 0
		tempfile operator`y'
		save "`operator`y''"
	}
}
clear 
forval y = 2002/ 2015 {
	append using "`operator`y''"
}
*Take last operatorname and this will be the source file for operatornames
duplicates drop
sort operatorid year
*Entity Type doesn't change by year and take last name
collapse (lastnm) operatorname entity_type, by(operatorid)
tempfile operators
save "`operators'"

************************
* GENERATOR- LEVEL DATA
************************
forval y = 2002 / 2015 {
	qui cd "$eia860/eia860`y'"
	
	local twodigit = substr("`y'", 3, .)
	*****IMPORT DATA - DIFF YEARS, DIFF FILE FORMATS *******
	if inrange(`y', 2002, 2003) import delimited using "GENY`twodigit'", clear
	
	else { // EXCEL Import - Feed import_ex file_string and excel options
		local st_two cellrange(A2)
		if inrange(`y', 2004, 2008)      import_ex "GenY`twodigit'.xls"
		else if `y' == 2009              import_ex "GeneratorY`twodigit'.xls" 
		else if `y' == 2010              import_ex "GeneratorsY`y'.xls"
		else if inrange(`y', 2011, 2012) import_ex "GeneratorY`y'.xlsx" `st_two'
		else                             import_ex "3_1_Generator_Y`y'.xlsx" `st_two'
	}	
	qui {
		standardize_id_variables
		
		*Define names to change to here.
		local nameplate nameplate_capacity
		local summer summer_capacity
		local winter winter_capacity
		
		capture rename nameplate `nameplate'
		capture rename nameplatecapacitymw `nameplate'
		capture rename summcap `summer'
		capture rename wintcap `winter'
		capture rename summercapacity `summer'
		capture rename wintercapacity `winter'
		capture rename summercapability `summer'
		capture rename wintercapability `winter'
		capture rename wind turbine_num
		capture rename windturbine turbine_num
		capture rename turbines turbine_num
		
		capture rename owner ownership
		capture rename deliverpowertransgrid        deliver_power_transgrid
		capture rename deliverpowertotransmissiongr deliver_power_transgrid
		capture rename (insvmonth insvyear) (operatingmonth operatingyear)
		
		*Keep only Wind
		keep if inlist(primemover, "WT", "WS")
		gen year = `y'
		
		local destring_vars nameplate_capacity summer_capacity winter_capacity ///
							operatingmonth operatingyear year facilityid turbine_num
		destring `destring_vars', replace
		
		if inrange(`y', 2004, 2012) keep `destring_vars' genid ownership deliver_power_transgrid
		else keep `destring_vars' genid ownership
		
		
		
		tempfile geni`y'
		qui save "`geni`y''"
	}
}
clear 
forval y = 2002 / 2015 {
	append using "`geni`y''"
}
* Documentation indicate that IPP and 

label var ownership "S = single, J = joint"

duplicates drop
tempfile gen_data
save "`gen_data'"

*****************************************
* WIND DATA (ONLY AVAILABLE 2013 - 2015)
*****************************************
/* NOTE: Wind Files have operatingmonth, operatingyear, and nameplate_capacity. These are
   the same variables as those in generatorid (I verified). Do not need to grab them here */
cd "$eia860"
forval y = 2013 / 2015 {
	import excel "eia860`y'\3_2_Wind_Y`y'.xlsx", sheet("Operable") cellrange(A2) firstrow clear
	qui {
		standardize_id_variables
		
		local ren_vars manufacturer_eia model_eia design_windspeed_eia turb_height_eia windclass_eia
		
		rename (predominantturbinemanufacturer predominantturbinemodelnumber ///
				designwindspeedmph turbinehubheightfeet windqualityclass) (`ren_vars')
		
		*keep `ren_vars' facilityid genid 
		gen year = `y'
		destring design_windspeed_eia turb_height_eia windclass_eia , replace
		tempfile wind`y'
		qui save "`wind`y''"
	}
}
clear
forval y = 2013 / 2015 {
	append using "`wind`y''"
}
replace design_windspeed_eia = . if design_windspeed_eia == 0 //unrealistic
duplicates drop
tempfile wind_data
save "`wind_data'"

* BRING ALL DATA-SOURCES TOGETHER
use "$repodir/temp/eia_plant_data", clear
merge m:1 operatorid using "`operators'", nogen keep (master matched)
merge 1:m facilityid year using "`gen_data'", keep (matched using) nogen
merge 1:1 facilityid year genid using "`wind_data'", nogen

order operatorid operatorname facilityid facilityname genid year
sort facilityid genid year
compress

gen operating_date = date(string(operatingyear) + string(operatingmonth), "YM")
bys facilityid (year): egen ope_date_min = min(operating_date)
bys facilityid (year): egen ope_date_max = max(operating_date)
 
format operating_date ope_date* %tdmonCCYY

gen ope_months_min = ope_date_min / 30
gen ope_months_max = ope_date_max / 30

* Create flag variable if facility is never in years with ISO variable data collection
bys facilityid: egen total_10_12 = total( inrange(year, 2010, 2012) )
gen not_in_iso_years = cond(total_10_12 == 0, 1, 0)

* Create flag variable if facility never in years that have balancing authority
bys facilityid: egen total_13_15 = total( inrange(year, 2013, 2015) )
gen not_in_ba_years = cond(total_13_15 == 0, 1, 0)

drop total_10_12 total_13_15


* Rich wants a weighted average of generators that deliver to powergrid
gen deliver_power_grid = cond(deliver_power_transgrid == "Y", 1, 0)
replace deliver_power_grid = . if deliver_power_transgrid == ""

* Calculated Weighted Average by capacity
preserve
	collapse (mean) deliver_power_transgrid = deliver_power_grid [weight = nameplate_capacity], by(facilityid year)
	tempfile deliver_power
	save "`deliver_power'"
restore
**************************************************
* Collapse from Generator to Facility Level
**************************************************
/* Sort by facilityid ID and descending on nameplate. We want information associated with
   largest generators. For ties, sort on generatorID so that the sort is replicable */
gsort facilityid year -nameplate_capacity genid

collapse (sum) turbine_num nameplate_capacity summer_capacity winter_capacity ///
		 (firstnm) operatorid operatorname entity_type facilityname state isortocode in_iso_rto ///
				   manufacturer_eia model_eia design_windspeed_eia windclass_eia ///
				   turb_height_eia balancingauthority nercregion ///
				   not_in_iso_years not_in_ba_years ///
				   ope_date_min ope_date_max ope_months_min ope_months_max zip ///
				   ownership regulatory_status sector_name sector_number latitude longitude, by(facilityid year)

merge 1:1 facilityid year using "`deliver_power'"
assert _merge == 3
drop _merge

rename (latitude longitude) (eia_lat eia_long)

* Treasury research 11 / 29 / 2015. FID 56790 Capacity needs to be changed
foreach v in nameplate summer winter {
	replace `v'_capacity = 100.8 if facilityid == 56790
}

label var nameplate_capacity "Nameplate capacity (MW)"
label var summer_capacity    "Summer Capacity (MW)"
label var winter_capacity    "Winter Capacity (MW)"

* Clarify Entity Type
replace entity_type = "Cooperative" 				if entity_type == "C"
replace entity_type = "Investor-Owned Utility" 	    if entity_type == "I"
replace entity_type = "Independent Power Producer" 	if entity_type == "Q"
replace entity_type = "Municipally-Owned Utility" 	if entity_type == "M"
replace entity_type = "Political Subdivision" 		if entity_type == "P"
replace entity_type = "Federally-Owned Utility" 	if entity_type == "F"
replace entity_type = "State-Owned Utility" 		if entity_type == "S"
replace entity_type = "Industrial" 					if entity_type == "IND"
replace entity_type = "Commercial" 					if entity_type == "COM"

replace manufacturer_eia = lower(manufacturer_eia)
replace model_eia = lower(model_eia)


compress
order operatorid operatorname facilityid facilityname year
sort  facilityid year
save "$repodir/temp/EIA_860.dta", replace
********************************************************************************
*							EIA 923 DATA
********************************************************************************
cd "$eia923"

* PROGRAM TO RETURN EIA YEAR DIRECTORY. ASSUMES EACH YEAR HAS ITS OWN FOLDER
* KEEPS SAME NAMING CONVENTION AS EIA DOWNLOAD
capture program drop get_923_direc
program define get_923_direc, rclass
	args year
	if inrange(`year', 2002, 2007) local ddir "f906920_`year'"
	else                           local ddir "f923_`year'"
	return local ddir "`ddir'"
end

********************************************
*SCHEDULE 2 - 5  - MONTHLY PRODUCTION DATA
********************************************
/* FOLLOWING LOOP:
 y = 2002/ 2015 - pull in year y
 y = 2016 - pull in old 2014 data with two facilities that were dropped in original 2014 data
*/
forval y = 2002 / 2016 {
	
	if `y' == 2016 {
		import excel "EIA923_Schedules_2_3_4_5_2014_OLD.xlsx", ///
		sheet("Page 1 Generation and Fuel Data") cellrange(A6:CS12179) firstrow clear
	}
	
	else {
		if `y' < 2011 { 
			local st_row cellrange(A8)
	
			if `y' == 2002                   local file_s "f906920y2002.xls"
			else if inrange(`y', 2003, 2007) local file_s "f906920_`y'.xls"
			else if `y' == 2008              local file_s "eia923December2008.xls"
			else if `y' == 2009              local file_s "EIA923 SCHEDULES 2_3_4_5 M Final 2009 REVISED 05252011.XLS"
			else                             local file_s "EIA923 SCHEDULES 2_3_4_5 Final 2010.xls"
	}
		else { //2012 - 2015
			local st_row cellrange(A6)
		
			if (`y' == 2011 | `y' == 2013) local file_s "EIA923_Schedules_2_3_4_5_`y'_Final_Revision.xlsx"
			else                           local file_s "EIA923_Schedules_2_3_4_5_M_12_`y'_Final_Revision.xlsx"
		}
	
		get_923_direc `y' //Grab directory based on year
		import excel "`r(ddir)'/`file_s'", sheet("Page 1 Generation and Fuel Data") firstrow `st_row' clear
	}
	
	qui {
		standardize_id_variables
		rename netgenerationmegawatthours annual_netgen
		
		if `y' == 2016 {
			keep if inlist(facilityid, 56414, 56415)
		}
		
		* Keep Only Wind & Drop Imputed Aggregate ID (all under 99999)
		qui keep if reportedfueltype == "WND" & facilityid != 99999
		keep facilityid year netgen* annual_netgen
		qui destring netgen* annual_netgen, replace
		*2012, 2014, 2015 change month name to abbrev. Ex: netgenjanuary -> netgenjan 
		if inlist(`y', 2012, 2014, 2015, 2016) renvars netgen*, trim(9)

		tempfile gen_923_`y'
		save "`gen_923_`y''"
	}
}
clear
forval y = 2002 / 2016 {
	append using "`gen_923_`y''"
}
* Make sure no dups by Facilityid - Year to prepare for reshape
duplicates drop
duplicates tag facilityid year, gen(dup)
assert dup == 0 
drop dup

* RESHAPE WIDE TO LONG. OBS LEVEL BECOMES FACILITYID - YEAR - MONTH
reshape long netgen, i(facilityid year) j(month, string)
*Change Month to str. ex. "jan" -> 1
gen mon = 0
local months_abbrev jan feb mar apr may jun jul aug sep oct nov dec
forval y = 1 / 12 {
	local abbrev: word `y' of `months_abbrev'
	qui replace mon = `y' if month == "`abbrev'"
}
drop month
rename mon month
duplicates drop

tempfile schedule_2_5
save "`schedule_2_5'"

*************************************************
* SCHEDULE 6 - 7 - ANNUAL GENERATION AND SALES
*************************************************
forval y = 2004 / 2015 {
	di "`y'"
	if `y' < 2011 {
		local row_start cellrange(A9)
		if inrange(`y',2004, 2010) & `y' != 2008 local file_s "`y' Nonutility Source and Disposition.xls"
		else if `y' == 2008                      local file_s "2008 Nonutility Source and Disposition Final version.xlsm"
	}
	else {
		local row_start cellrange(A5)
		if `y' == 2013 local file_s "EIA923_Schedules_6_7_NU_SourceNDisposition_2013_Final.xlsx"
		else           local file_s "EIA923_Schedules_6_7_NU_SourceNDisposition_`y'_Final_Revision.xlsx"
	}
	get_923_direc `y' //grab directory based on year
	import_ex "`r(ddir)'/`file_s'" `row_start'
	qui {
		standardize_id_variables
		
		*Revenue from Resale appears after 2011
		local keepvars facilityid year grossgeneration retailsales salesforresale totaldisposition
		if `y' < 2011 keep `keepvars'
		else {
			capture rename revenuefromresalethousanddo revenuefromresale
			destring revenuefromresale, replace
			keep `keepvars' revenuefromresale
		}
		destring grossgeneration retailsales salesforresale totaldisposition, replace
		tempfile schedule_6_`y'
		qui save "`schedule_6_`y''"
	}
}
clear
forval y = 2004 / 2015 {
	append using "`schedule_6_`y''"
}
* DEAL WITH DUPLICATES
duplicates drop

* These two facilties have all zeroes for one of the obs in 2006. Keep row with data
drop if facilityid == 10294 & year == 2006 & retailsales == 0
drop if facilityid == 55396 & year == 2006 & grossgen == 0

*These two facilitises have duplicates but are not wind farms, so can drop
drop if facilityid == 10523 
drop if facilityid == 55592 

merge 1:m facilityid year using "`schedule_2_5'"
order facilityid year month
sort facilityid year month
compress
keep if _merge != 1 //only interested if it has production data
drop _merge
rename grossgeneration annual_grossgen

label var retailsales       "Electricity Sold (MWH) to Retail Customers"
label var salesforresale    "Electricity Sold(MWH) wholesale"
label var revenuefromresale "$(Thousand dollars from wholesale"
label var annual_grossgen   "Total Annual Gross Gen (MWH)"
label var annual_netgen     "Total Annual Net Gen (MWH)"
label var totaldisposition "Total Outgoing Elec (MWH)"

save "$repodir/temp/EIA_923.dta", replace
********************************************************************************
* 			CLEAN EIA 861M (Formerly 826) - SALES REVENUE BY STATE DATA-SET
********************************************************************************
import excel "$eia\eia_861M\sales_revenue.xlsx", clear

*Data file has four sections: industrial, transportation, other, total 
local rename_vars year month state data_status
*Add the four sections for rename
foreach pre in res com ind trans oth tot {
	foreach t in rev sales customers price {
		local rename_vars `rename_vars' `pre'_`t'
	}
}
di "`rename_vars'"
rename (_all) (`rename_vars')

drop in 1/3
drop if regexm(year, "The sector")
destring year tot_price month, replace
keep if inrange(year, 2002, 2015)
keep year month state tot_price

*la var res_price "Residential Price (EIA826) in Cents/kWh"
*la var com_price "Commercial Price (EIA826) in Cents/kWh"
*la var ind_price "Industrial Price (EIA826) in Cents/kWh"
*la var oth_price "Other Price (EIA826) in Cents/kWh"
la var tot_price "Avg Retail Elec. Price (EIA861M) in Cents/kWh for state"
rename tot_price state_avg_price

compress
save "$generated_data/EIA_826.dta", replace
*************************** COMBINE EIA DATASETS *******************************
use "$repodir/temp/EIA_860.dta", clear
merge 1:m facilityid year using "$repodir/temp/EIA_923.dta", nogen keep(matched)

sort facilityid year month

* Produce EIA dynamic data-set with changing information
local static_variables facilityname state ope_date_min ope_date_max ///
	                   ope_months_min ope_months_max zip design_windspeed_eia turb_height_eia ///
		               manufacturer_eia model_eia isortocode in_iso_rto balancingauthority nercregion ///
		               not_in_iso_years not_in_ba_years windclass_eia entity_type eia_lat eia_long
		 
preserve
	drop `static_variables'
	save "$generated_data/eia_dynamic.dta", replace
restore

* PRODUCE STATIC DATA-SET	
keep facilityid year `static_variables'

/* GOING TO TAKE MODE OF EIA MANUFACTURER AND EIA MODEL

	MODE CODE WILL FAIL IF THERE IS NO MODE
	TWO ISSUES:
		- DIFFERENT SPELLINGS (NEED TO STANDARDIZE)
		- DIFFERENT TURBINES LISTED
			-GOOGLE SEARCHED WHICH WAS CORRECT
*/

qui {
	* REPLACING FACILITIES WITH UNKNOWN - MANUAL LOOKUP
	replace manufacturer_eia = "danwin" if facilityid == 54650
	replace model_eia = "23/160" if facilityid == 54650
	replace model_eia = "1.5 s" if facilityid == 508

	* Set to missing if unknown
	replace model_eia = "" if model_eia == "unknown" | model_eia == "ukn"

	* Some manufacturer and models are reversed and need to be switched
	* Swap if manufacturer has numbers and modell doesn't
	gen swap_flag = regexm(manufacturer_eia, "[0-9]") & ! regexm(model_eia, "[0-9]") 
	gen swap = cond(swap_flag == 1,manufacturer_eia, "N/A")
	replace manufacturer_eia = model_eia if swap_flag
	replace model_eia = swap if swap_flag
	drop swap

	* STANDADIZE MANUFACTURER NAMES
	replace manufacturer_eia = "ge" if regexm(manufacturer_eia, "gen") & regexm(manufacturer_eia, "elec")
	foreach m in acciona clipper guodian siemens samsung sany nordex hyundai senvion suzlon vestas mitsubishi nedwind {
		replace manufacturer_eia = "`m'" if regexm(manufacturer_eia, "`m'")
	}
	replace manufacturer_eia = "clipper"    if regexm(manufacturer_eia, "cipper")
	replace manufacturer_eia = "danwin"     if manufacturer_eia == "danwind"
	replace manufacturer_eia = "siemens"    if manufacturer_eia == "siemans"
	replace manufacturer_eia = "vestas"     if manufacturer_eia == "vesta"
	replace manufacturer_eia = "neg micon"  if regexm(manufacturer_eia, "micon") | manufacturer_eia == "neg micron"
	replace manufacturer_eia = "fuhrlander" if inlist(manufacturer_eia, "fuhrlaender", "furhlander")
	replace manufacturer_eia = "ge"         if inlist(manufacturer_eia, "g.e.", "ge wind", "ge energy")
	replace manufacturer_eia = "siemens"    if manufacturer_eia == "seimens"
	
	* Repower renamed to Senvion
	replace manufacturer_eia = "senvion" if manufacturer_eia == "repower"
	
	* Leitner-poma of america is North american branch of leitwind. Only Leitwind is in our powercurve
	replace manufacturer_eia = "leitwind"     if manufacturer_eia == "leitner-poma of america"
	replace manufacturer_eia = "mitsubishi"   if inlist(manufacturer_eia, "mitshubishi", "mitsubushi")
	replace manufacturer_eia = "mitsubishi" if manufacturer_eia == "mhi"
	replace manufacturer_eia = "kenetech"     if inlist(manufacturer_eia, "kennetch", "kennetech", "kentech")
	replace manufacturer_eia = "goldwind"     if manufacturer_eia == "goldwin"
	
	*This facility has "ge ess-sle" for model. Currently model is just 1.5
	replace model_eia = "1.5 ess-sle"   if year == 2013 & facilityid == 54454
	replace manufacturer_eia = "ge"     if year == 2013 & facilityid == 54454

	* STANDARDZE MODEL NAMES
	replace model_eia = "1.5 sle"      if model_eia == "1.5sle"
	replace model_eia = "g87-2.0"      if model_eia == "g87" //only one G87
	replace model_eia = "g90-2.0"      if model_eia == "g90" //only one G90
	
	*Take manufacturer out of moel name
	foreach model in ge nordex siemens liberty clipper acciona micon vensys vestas enertech danwin zond mitsubishi{
		replace model_eia = subinstr(model_eia, "`model'", "", .)
	}
	replace model_eia = ltrim(model_eia)

	
	local ge manufacturer_eia == "ge"
	replace model_eia = "1.5 sle" if `ge' & regexm(model_eia, "1.5") & regexm(model_eia, "sle")
	replace model_eia = "1.5 xle" if `ge' & regexm(model_eia, "1.5") & regexm(model_eia, "xle")
	replace model_eia = "1.6 xle" if `ge' & regexm(model_eia, "1.6") & regexm(model_eia, "xle")
	
	
	capture program drop vague_to_specific
	program define vague_to_specific
	syntax [name], vague_model(str) specific_model(str)
		bys facilityid: egen specific = total(model_eia == "`specific_model'")
		replace model_eia = "`specific_model'" if model_eia == "`vague_model'" & specific > 0
		drop specific
	end
	
	
	*These list S64 in some years and S64-1250 in other years
	bys facilityid: egen specific = total(model_eia == "s64-1250")
	replace model_eia = "s64-1250" if (model_eia == "s-64" | model_eia == "s64") & specific > 0
	drop specific
	
	*Do same with S and S88
	bys facilityid: egen specific = total(model_eia == "s88-2100")
	replace model_eia = "s88-2100" if inlist(model_eia, "s-88", "s88", "s 88") & specific > 0
	drop specific
	
	/* A lot of years just have 1.5 which is inconclusive. If another year within the faciltyi
	   has 1.5 s. REplace 1.5 with 1.5s
	*/
	vague_to_specific, vague_model("1.5") specific_model("1.5 s")
	
	vague_to_specific, vague_model("nm54") specific_model("nm54/950")

	vague_to_specific, vague_model("nm48") specific_model("nm48/750")
	vague_to_specific, vague_model("750") specific_model("nm48/750")
	
	vague_to_specific, vague_model("nm52") specific_model("nm52/900")
	vague_to_specific, vague_model("n-60") specific_model("n60/1300")
	vague_to_specific, vague_model("65kw") specific_model("ntk 65/13")
	vague_to_specific, vague_model("ntk75") specific_model("ntk 75/15")
	vague_to_specific, vague_model("v-17") specific_model("v17-75")
	
	vague_to_specific, vague_model("1.85") specific_model("1.85-82.5")
	vague_to_specific, vague_model("v47") specific_model("v47-660")
	vague_to_specific, vague_model("v-47") specific_model("v47-660")
	vague_to_specific, vague_model("v90") specific_model("v90-1.8")
	vague_to_specific, vague_model("v90") specific_model("v90-3.0")
	vague_to_specific, vague_model("v90") specific_model("v90-2.0")
	vague_to_specific, vague_model("v112") specific_model("v112-3.0")
	vague_to_specific, vague_model("n90") specific_model("n90/2500")
	vague_to_specific, vague_model("sle") specific_model("1.5 sle")
	vague_to_specific, vague_model("900") specific_model("dw54-900")
	vague_to_specific, vague_model("dw54") specific_model("dw54-900")
	vague_to_specific, vague_model("1.5") specific_model("1.5 sle")
	vague_to_specific, vague_model("v82") specific_model("v82-1.65")
	vague_to_specific, vague_model("g114") specific_model("g114-2.0")
	vague_to_specific, vague_model("v100") specific_model("v100-2.0")
	vague_to_specific, vague_model("1.85") specific_model("1.85-87")
	vague_to_specific, vague_model("1.3") specific_model("swt-1.3-62")
	vague_to_specific, vague_model("1.5 mw") specific_model("aw77/1500")
	vague_to_specific, vague_model("g9x-2.0mw") specific_model("g90-2.0")
	vague_to_specific, vague_model("g8xx") specific_model("g80-2.0")
	vague_to_specific, vague_model("xle") specific_model("1.5 xle")
	vague_to_specific, vague_model("nm82") specific_model("nm82/1650")
	vague_to_specific, vague_model("m750") specific_model("m750-400/100")
	vague_to_specific, vague_model("m700") specific_model("m700-225/40")
	vague_to_specific, vague_model("-600") specific_model("m1500-600/150")
	vague_to_specific, vague_model("750") specific_model("m750-400/100")
	vague_to_specific, vague_model("nm 72c") specific_model("nm72c/1500")
	vague_to_specific, vague_model("v17") specific_model("v17-90")
	vague_to_specific, vague_model("40") specific_model("e44-40")
	vague_to_specific, vague_model("1.5 mw") specific_model("gw 82/1500")
	vague_to_specific, vague_model("gw1500") specific_model("gw 87/1500")
	vague_to_specific, vague_model("1.5") specific_model("1.5 se")
	vague_to_specific, vague_model("1.5") specific_model("nm72c/1500")
	vague_to_specific, vague_model("v27") specific_model("v27-225")
	vague_to_specific, vague_model("v-27") specific_model("v27-225")
	vague_to_specific, vague_model("27") specific_model("v27-225")
	vague_to_specific, vague_model("v66") specific_model("v66-1.65")
	vague_to_specific, vague_model("250") specific_model("mwt-250")
	vague_to_specific, vague_model("65/13") specific_model("ntk 65/13")
	vague_to_specific, vague_model("v80") specific_model("v80-1.8")
	vague_to_specific, vague_model("v-80") specific_model("v80-1.8")
	vague_to_specific, vague_model("v-82") specific_model("v82-1.65")
	vague_to_specific, vague_model("82") specific_model("v82-1.65")
	vague_to_specific, vague_model("-1.5") specific_model("1.5 sle")
	vague_to_specific, vague_model("2.3 - 93") specific_model("swt-2.3-93")
	vague_to_specific, vague_model("v44") specific_model("v44-600")
	vague_to_specific, vague_model("gw77") specific_model("gw 77/1500")
	vague_to_specific, vague_model("v-17") specific_model("v17-90")
	vague_to_specific, vague_model("v-90") specific_model("v90-1.8")
	vague_to_specific, vague_model("2.3") specific_model("swt-2.3-93")
	vague_to_specific, vague_model("1.5") specific_model("1.5-77")
	vague_to_specific, vague_model("v47.66") specific_model("v47-660")
	vague_to_specific, vague_model("n100") specific_model("n100/2500")
	vague_to_specific, vague_model("160") specific_model("23/160")
	vague_to_specific, vague_model("600") specific_model("mwt-600 (45m)")
	vague_to_specific, vague_model("mwt-600") specific_model("mwt-600 (45m)")
	vague_to_specific, vague_model("mwt-600") specific_model("mwt-600 (47m)")
	vague_to_specific, vague_model("2.3") specific_model("swt-2.3-108")
	vague_to_specific, vague_model("2.3") specific_model("swt-2.3-101")
	vague_to_specific, vague_model("siemans 93") specific_model("swt-2.3-93")
	vague_to_specific, vague_model("-1.6") specific_model("1.6 sle")
	vague_to_specific, vague_model("v-100") specific_model("v100-1.8")
	vague_to_specific, vague_model("k100") specific_model("k100 2.5")
	vague_to_specific, vague_model("v-90") specific_model("v90-3.0")
	vague_to_specific, vague_model("s-97") specific_model("s97-2100")
	vague_to_specific, vague_model("s97") specific_model("s97-2100")
	vague_to_specific, vague_model("v100") specific_model("v100-1.8")
	vague_to_specific, vague_model("1.6") specific_model("1.6 xle")
	vague_to_specific, vague_model("g 87") specific_model("g87-2.0")
	*There is no n1000
	vague_to_specific, vague_model("n1000") specific_model("n54/1000")
	vague_to_specific, vague_model("1000") specific_model("n54/1000")
	vague_to_specific, vague_model("g97") specific_model("g97-2.0")
	vague_to_specific, vague_model("n117") specific_model("n117/2400")
	vague_to_specific, vague_model("1.7 mw") specific_model("1.7-100")
	vague_to_specific, vague_model("g5x-850kw") specific_model("g52-850")
	vague_to_specific, vague_model("n-54") specific_model("n54/1000")
	vague_to_specific, vague_model("108m") specific_model("swt-2.3-108")

	* FOR FACILIITIES WITH DIFFERENT MANUFACTURERS - GOOGLE SEARCH WHICH IS CORRECT
	replace manufacturer_eia = "zond"         if facilityid == 7966
	replace manufacturer_eia = "bonus"     if facilityid == 10815
	replace manufacturer_eia = "neg micon"    if facilityid == 56002
	* GOOGLE search-these wer elabeled as siemens but actually senvion
	replace manufacturer_eia = "senvion"      if facilityid == 57757
	replace manufacturer_eia = "senvion"      if inlist(facilityid, 57725, 56874, 56878, 57586)
	
	replace model_eia = "1.5 s" if model_eia == "1.5s"

	* CORRECT FACILITIES THAT HAVE DIFFERENT MODELS - GOOGLE SEARCHED
	replace model_eia = "b62/1300"      if facilityid == 10815
	replace model_eia = "micon 108"   if facilityid == 54681 
	
	replace model_eia = "v42-600" if facilityid == 50281
	
	
	replace model_eia = "1.5 sle"     if facilityid == 55871
	replace model_eia = "v47-660"     if facilityid == 55980
	replace model_eia = "v47-660"     if facilityid == 56112
	
	replace model_eia = "1.5 sle"     if facilityid == 56172
	replace model_eia = "1.5 sle"     if facilityid == 56173
	replace model_eia = "1.5 sle"     if facilityid == 56174
	
	replace model_eia = "mwt-1000"    if model_eia == "mwt1000"
	replace model_eia = "aw 77/1500"  if facilityid == 56669
	
	replace model_eia = "mwt-95/2.4"  if model_eia == "mwt95"
	replace model_eia = "mwt-62/1.0"  if model_eia == "mwt62"
	
	*G78 turbine doesn't exist. Its G87. Looked it up
	replace model_eia = "g87-2.0"     if facilityid == 58141
	
	replace model_eia = "swt-2.3-101" if model_eia == "swt2.3-101"
	replace model_eia = "swt-2.3-108" if inlist(model_eia, "swt 2.3-108", "swt-2.23-108")
	
	replace model_eia = "1.85-87"     if facilityid == 58765
	replace model_eia = "1.6-103"     if facilityid == 58768
	
	*This one had incorrect value  1.179 is not a turbine
	*http://nawindpower.com/invenergy-wraps-up-spring-canyon-expansion-wind-energy-center
	replace model_eia = "1.7-100"    if facilityid == 58769
	
	replace model_eia = "1.85-87"     if facilityid == 58774 
	
	replace model_eia = "1.5 xle"     if facilityid == 58836

	replace model_eia = "v100-2.0"    if facilityid == 58938
	
	replace model_eia = "1.7-100"     if inlist(model_eia, "1.7 mw 100m 60hz", "1.7x100")
	
	replace model_eia = "1.6-82.5"    if facilityid == 59003
	replace model_eia = "1.7-100"     if facilityid == 59083
	
	replace model_eia = "1.7-100"     if facilityid == 59284 
	replace model_eia = "1.7-100"     if facilityid == 59311
	replace model_eia = "1.7-100"     if facilityid == 59312
	replace model_eia = "se9320iii-3" if facilityid == 59639

	replace model_eia = "ltw-77"      if facilityid == 59797
	replace model_eia = "a-1500-70"   if facilityid == 57350
	
	* CORRECTING OBS THAT HAVE MODELS THAT DO NOT EXIST - GOOGLE SEARCHES
	
	* Correcting GE models that are not possible (errors)
	* No such thing as 1.79-100
	replace model_eia = "1.7-100" if inlist(model_eia, "ge 1.179-100", "1.79-100")
	
	*Looked up this turbine because 1.179 xle is not a turbine
	replace model_eia = "1.7-100" if facilityid == 60069
	*Looking up bad neg micon turbines (don't actually exist)
	replace model_eia = "nm48/750" if facilityid == 55367
	
	replace model_eia = "nm110/4200" if model_eia == "m110" & manufacturer_eia == "neg micon"
	

	replace model_eia = "v42-600"   if facilityid == 10823
	
	replace model_eia = "v17-90"        if facilityid == 10005
	replace manufacturer_eia = "vestas" if facilityid == 10005
	
	replace model_eia = "v82-1.65"  if facilityid == 56376
	replace model_eia = "v82-1.65"  if facilityid == 58995
	replace model_eia = "s88-2100"  if facilityid == 56753

	replace model_eia = "swt-2.3-93" if facilityid == 56394
	replace model_eia = "swt-2.3-93" if facilityid == 56592
	replace model_eia = "swt-2.3-93" if facilityid == 56649
	replace model_eia = "nm110/4200" if facilityid == 50485
	
	replace model_eia = "c96"        if facilityid == 56630
	
	replace model_eia = "aw77/1500" if model_eia == "aw 1.5" & manufacturer_eia == "acciona"
	replace model_eia = "dw54-900"   if facilityid == 58511
	
	replace model_eia = "swt-2.3-93" if facilityid == 56638
	replace model_eia = "s88-2100" if facilityid == 56789
	
	replace model_eia = "mwt-92/2.4" if model_eia == "mwt92/2.4"
	replace model_eia = "gw87-1.5" if facilityid == 57570
	replace model_eia = "g90-2.0" if facilityid == 57268
	
	replace model_eia = "v82-1.65" if inlist(facilityid, 58464, 58465)
	replace model_eia = "g90-2.0" if facilityid == 57775
	
	replace model_eia = "1.6-100" if inlist(facilityid, 58126, 58127)
	
	replace model_eia = "1.6 xle" if inlist(facilityid, 57590, 57956)
	
	replace model_eia = "1.7-100" if facilityid == 58587
	
	replace model_eia = "swt-2.3-93"  if facilityid == 56424
	replace model_eia = "swt-2.3-93" if facilityid == 56763
	
	replace model_eia = "v82-1.65" if facilityid == 56961
	replace model_eia = "v82-1.65" if facilityid == 57296
	
	replace model_eia = "m66/13"   if facilityid == 50001
	
	replace model_eia = "b19/120" if facilityid == 56214
	replace model_eia = "nm52/900" if facilityid == 55741
	
	replace model_eia = "s88-2100" if facilityid == 56789
	
	replace model_eia = "s88-2100" if facilityid == 56560	
	
	replace model_eia = "v82-1.65" if facilityid == 56402
	replace manufacturer_eia = "vestas" if facilityid == 56402
	
	replace model_eia = "v82-1.65" if facilityid == 57257
	
	replace model_eia = "1.5 s" if facilityid == 55805
	
	replace model_eia = "1.6-100" if facilityid == 58203
	
	replace model_eia = "1.5 sle" if facilityid == 54300
	
	replace model_eia = "1.5 s" if facilityid == 56573
	replace model_eia = "1.5 sle" if facilityid == 56980
	replace model_eia = "1.5 sle" if facilityid == 56981
	replace model_eia = "1.5 sle" if facilityid == 57153
	replace model_eia = "1.5 xle" if facilityid == 57211
	replace model_eia = "1.6 xle" if facilityid == 57357
	replace model_eia = "1.6 sle" if facilityid == 57210
	replace model_eia = "1.5 sle" if facilityid == 57631
	replace model_eia = "1.5 sle" if facilityid == 57632
	replace model_eia = "1.5 sle" if facilityid == 57756
	replace model_eia = "1.6 xle" if facilityid == 57855
	replace model_eia = "1.7-100" if facilityid == 58580
	replace model_eia = "1.7-100" if facilityid == 58594
	
	replace model_eia = "1.6 xle" if facilityid == 58078
	replace model_eia = "1.6-100" if facilityid == 58088
	
	replace model_eia = "mm92-2.0" if facilityid == 56666
	replace model_eia = "mm92-2.0" if facilityid == 56874
	replace model_eia = "mm92-2.0" if facilityid == 56878
	replace model_eia = "mm92-2.0" if facilityid == 56969
	replace model_eia = "mm92-2.0" if facilityid == 57131
	
	replace model_eia = "ntk 150/25" if facilityid == 54687

	
	
}
* GENERATE MODE FOR FACILTIY AND MODEL
foreach var in manufacturer_eia model_eia {
	bys facilityid: egen `var'_mode = mode(`var')
	*There should be no obs with mode missing if variable is present
	qui count if `var' != "" & `var'_mode == ""
	assert `r(N)' == 0
}
drop manufacturer_eia model_eia swap_flag
rename (manufacturer_eia_mode model_eia_mode) (manufacturer_eia model_eia)


/* ALL OTHER STATIC_VARIABLES:
	TAKE 2014 VALUE UNLESS MISSING OTHERWISE TAKE LAST NON-MISSING
*/
gen is14 = cond(year == 2014, 1, 0)
foreach var in `static_variables' {
	qui gen `var'_2014_value = `var' if is14
}
collapse (lastnm) `static_variables' (firstnm) *_2014_value, by(facilityid)

*Replace with last non-missing if missing 2014 value
foreach var in `static_variables'{
	capture replace `var'_2014_value = `var' if `var'_2014_value == .
	capture replace `var'_2014_value = `var' if `var'_2014_value == ""
	
	drop `var'
	rename `var'_2014_value `var'
	label var `var' ""
}

label var ope_date_min     "Earliest date of start of commercial operation (EIA 860)"
label var ope_date_max     "Lastest date of start of commercial operation (EIA 860)"
label var ope_months_min   "Min # of months in operation since 1/1/1960"
label var ope_months_max   "Max # of months in operation since 1/1/1960"

label var state "State where Facility resides"
label var zip   "Zipcode of Facility"

label var in_iso_rto           "Binary variable whether in an ISO/RTO"
label var isortocode           "Indicates RTO/ISO of territory where plant resides"
label var balancingauthority   "BA manages supply and demand of elec in an area"
label var nercregion           "Nerc Region plant is located in"

label var not_in_iso_years " = 1 if no obs in years of EIA with ISO info (2010-2012)"
label var not_in_ba_years " = 1 if no obs in years of EIA with Balancing Authority Data (2013-2015)"
compress
save "$generated_data/eia_static.dta", replace
********************************************************************************
tempsetup
capture log close
exit
