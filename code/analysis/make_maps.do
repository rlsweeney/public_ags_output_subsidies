* CREATE MAPS OF SAMPLE WIND FARM LOCATIONS
********************************************************************************
local fname make_maps

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup
* this code uses tabout
//ssc install tabout

capture log close
log using "$outdir/logs/`fname'.txt", replace
********************************************************************************

********************************************************************************
* this code uses spmap, shp2dta, and mif2dta
//ssc install spmap
//ssc install shp2dta
//ssc install mif2dta
* see http://www.stata.com/support/faqs/graphics/spmap-and-maps/ for more information
********************************************************************************

/* DOWNLOAD SHAPEFILES - this only needs to be done once */
* source: 2014 NOAA States and Territories shapefile
* http://www.nws.noaa.gov/geodata/catalog/national/html/us_state.htm
* retrieved March 13, 2015 @ 4:30 PM

/* CONVERT SHAPEFILES FOR SPMAP - this only needs to be done once 
* cd "$dropbox/Analysis/Results/mapping"
* shp2dta using s_16de14, database(statesdb) coordinates(statescoord)
use statesdb, clear
save $repodir/generated_data/statesdb, replace
use statescoord, clear
save $repodir/generated_data/statescoord, replace
*/

** BRING IN DATA
use $repodir/generated_data/panel_reg_data, clear
keep if insample
rename eia_lat turbinelat
rename eia_lon turbinelong
gen firstmonth = month(ope_date_min)
* collapse data to cross-section (locations, 1603 flag, firstyear, and firstmonth are unique)
collapse turbinelat turbinelong flag_1603 nameplate firstyear firstmonth, by(facilityid state)
gen STATE = state //decode state, gen(STATE)
* merge to shapefile databaste and eliminate AK, HI, and territories from data
merge m:1 STATE using "$repodir/generated_data/statesdb"
drop if FIPS=="02" | FIPS=="60" | FIPS=="66" | FIPS=="15" | FIPS=="72" | FIPS=="78"
drop _merge
gen id = _n
* create labels for legend
label define vals1603 0 "PTC" 1 "1603"
lab val flag_1603 vals1603
* generate and save maps - pre-period vs. policy-period PTC vs. 1603
gen cat = .
replace cat = 0 if firstyear<=2008
replace cat = 1 if inrange(firstyear,2009,2012) & flag_1603==0
replace cat = 2 if inrange(firstyear,2009,2012) & flag_1603==1
* create labels for legend
label define cats 0 "Pre-Policy: PTC" 1 "Policy: PTC" 2 "Policy: 1603"
lab val cat cats
* flatten gradient for scaling shape size
gen log_cap = log(nameplate_capacity) + 1

* full 1603 period sample - color
spmap using $repodir/generated_data/statescoord, id(id) ///
	point(x(turbinelong) y(turbinelat) proportional(log_cap) ///
	select(keep if firstyear>=2009 & firstyear<=2012) ///
	by(cat) shape(Dh Oh) ocolor(midblue red) osize(medthick medthick) size(*0.5) legenda(on) ) ///
	legend(size(*2) rowgap(1.2)) ///
	note("Note: Marker sizes are proportional to log generating capacity.")
graph export "$outdir/figures/map_2009to2012.png", as(png) width(900) replace

* baseline bandwidth - color
spmap using $repodir/generated_data/statescoord, id(id) ///
	point(x(turbinelong) y(turbinelat) proportional(log_cap) ///
	select(keep if firstyear>=2008 & firstyear<=2009) ///
	by(cat) shape(+ Dh Oh) ocolor(green midblue red) osize(medthick medthick medthick) size(*0.65) legenda(on) ) ///
	legend(size(*2) rowgap(1.2)) ///
	note("Note: Marker sizes are proportional to log generating capacity.")
graph export "$outdir/figures/map_2008to2009.png", as(png) width(900) replace

********************************************************************************
tempsetup
capture log close
exit

