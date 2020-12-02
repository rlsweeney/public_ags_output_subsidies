* Pull in all turbine powercurves 
clear
local fname prep_power_curve

global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

* Clear Temp directory
tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************
global powercurves "$dropbox/Data/public/Databasepowercurves(August2015)"
********************************************************************************
* Program to lower manufacturer and model names
capture program drop lower_names
program define lower_names
	foreach var in turbinemanufacturer turbinemodel {
		replace `var' = lower(`var')
		replace `var' = trim(`var')
	}
end
***********************************************************************
* POWER CURVES FROM http://www.wind-power-program.com/download.htm
***********************************************************************

cd "$powercurves"

*Search cursively for power curve files
if c(os) == "MacOSX" {
	! find `pwd` -name *.pow > filenames.txt
}
else if c(os) == "Windows" {
	! dir *.pow /b /s > filenames.txt
}

* LOOP THROUGH ALL OF THE POW FILES AND THEN APPEND
local counter = 0
file open all_powercurves using filenames.txt, read text
file read all_powercurves f
while r(eof) == 0 { //go until you reach end of file(eof)

	qui infile str100 turbinfo1-turbinfo5 str10 w1-w30 str100 notes1-notes250 ///
		using "`f'", clear 
	qui egen str1000 note = concat(notes*), punct(" ")
	drop notes*
	gen fname = "`f'"
	local counter = `counter' + 1
	tempfile power_curve`counter'
	qui save "`power_curve`counter''"
	file read all_powercurves f
}
file close all_powercurves

clear 
forval y = 1 / `counter' {
	append using "`power_curve`y''"
}

replace fname = substr(fname, 85, .)

destring w*, replace
compress
gen source = "windpowerprogram/download"
ren turbinfo1 all
destring turbinfo*, replace

ren turbinfo2 rotordiameter
ren turbinfo4 cutoutspeed
ren turbinfo5 cutinspeed


* CREATE TURBINEMANUFACTURER
gen first_space = strpos(all, " ")
gen turbinemanufacturer = substr(all, 1, first_space - 1)
drop first_space

replace turbinemanufacturer = "GE"        if inlist(turbinemanufacturer, "General",  "GE Energy")
replace turbinemanufacturer = "Suzlon"    if substr(all, 1, 6) == "Suzlon" 
replace turbinemanufacturer = "Vergnet"   if substr(all, 1, 7) == "Vergnet"
replace turbinemanufacturer = "Repower"   if substr(all,1, 7) == "Repower"
replace turbinemanufacturer = "Vestas"    if turbinemanufacturer == "Vesta"
replace turbinemanufacturer = "f3 Energy" if turbinemanufacturer == "f3"

* CREATE TURBINEMODEL - EVERYTHING AFTER TURBINEMANUFACTURER
gen turbinemodel = substr(all, strlen(turbinemanufacturer) + 1, .)
order all turbinemanufacturer turbinemodel


*Get rid of stuff after model. Ex "Manufacturer's graph"
foreach ending in  "(M" "(N" "(U" "(f" "(R" "(C" "(I" {
	gen position = strpos(turbinemodel, "`ending'")
	* Grab from beginning up to start of manu
	replace turbinemodel = substr(turbinemodel , 1 , position - 2 ) if position != 0
	drop position
}
replace turbinemodel = subinstr(turbinemodel, "neral Electric", "", 1)

/* Other Power Curve sources have values for every half of a meter.
   use linear interpolation for power curves at half-m/s for new data */
gen w0 = 0 
order all turbinemanufacturer turbinemodel rotordiameter turbinfo3 cutoutspeed cutinspeed w0
forval i = 0 / 29 {
	local j = `i' + 1
	gen w`i'_5 = (w`i'+ w`j') / 2
	* If next one is 0, replace this as 0
	replace w`i'_5 = 0 if w`j' == 0
}
lower_names
drop all rotordiameter turbinfo3 cutoutspeed cutinspeed note

* DEAL WITH DUPLICATES TO DEAL WITH MERGE

* KEEP GAIAI FROM NREL
drop if turbinemodel == "13m 11kw" & regexm(fname, "MG")

* ONE SENVION TURBINEMODEL DOESN'T MATCH IT'S FILENAME
replace turbinemodel = "3.4 mw 104m" if turbinemodel == "3.4mw 114m" & regexm(fname, "104")

drop if turbinemodel == "3.7m 1.9kw" & regexm(fname, "MCS") 

drop if turbinemodel == "windspot 3.5kw 4.05m" & regexm(fname, "Certification test graph")

drop if turbinemodel == "vawt 2.6m equiv 2.5kw" & regexm(fname, "Table")

drop if turbinemodel == "v82-1.65mw" & regexm(fname, "MT")

*These are the exact same. Exploiting a filename difference to drop one
drop if turbinemodel == "huaying hy5-ad5.6 5.6m 5kw" & regexm(fname, "Revolution")

tempfile powercurves
save "`powercurves'"

*************************************
* POWER CURVES FROM Joern Huenteler
*************************************
import excel using "$dropbox/Data/proprietary/powercurves/powercurves_from_joern_huenteler.xlsx", clear
ren (A-E) (id turbinemanufacturer turbinemodel capacity all)
ren (F-BN) (w0 w0_5 w1 w1_5 w2 w2_5 w3 w3_5	w4 w4_5 w5 w5_5 w6 w6_5 w7 w7_5 w8 w8_5 w9 w9_5 w10 w10_5 ///
            w11 w11_5 w12 w12_5 w13	w13_5 w14 w14_5	w15	w15_5 w16 w16_5	w17	w17_5 w18 w18_5	w19	w19_5 ///
			w20	w20_5 w21 w21_5	w22	w22_5 w23 w23_5	w24	w24_5 w25 w25_5	w26	w26_5 w27 w27_5	w28	w28_5 ///
			w29	w29_5 w30)
gen source = "Joern Huenteler"

lower_names
replace turbinemanufacturer = "ge" if turbinemanufacturer == "ge energy"
replace turbinemanufacturer = "senvion" if turbinemanufacturer == "repower"
drop id all capacity
tempfile joern_curves
save "`joern_curves'"

*************************************
* JULY 7, POWERCURVES FOUND BY RICH
**************************************
import excel "$dropbox/Data/proprietary/powercurves/Power_curves_TWP_1603.xls", sheet("Power_curves") firstrow clear
renvars, lower
drop manid turbid conditions
rename (manufucturername turbinename) (turbinemanufacturer turbinemodel)
lower_names
* RENAME WIND Variables
forval y = 0 / 35 {
	if `y' != 35 local wind_names `wind_names' w`y' w`y'_5
	else local wind_names `wind_names' w`y'
}
rename (powerkwat-bw) (`wind_names')

drop if turbinemodel == "-"
gen source = "TWP"
*Other powercurves only go up to 30
drop w30_5-w35

replace turbinemanufacturer = "neg micon" if turbinemanufacturer == "micon"
replace turbinemanufacturer = "aerodyn" if regexm(turbinemanufacturer, "aerodyn")
replace turbinemanufacturer = "ge" if turbinemanufacturer == "ge energy"
replace turbinemanufacturer = "fuhrlander" if turbinemanufacturer == "fuhrländer"
replace turbinemanufacturer = "senvion" if turbinemanufacturer == "repower"
********************************************************************************
/* 							COMBINE THREE POWERCURVE SOURCES

HERE IS THE PRIORITY:
	- TWP
	- WEBSITE
	- JOERN
	
BY USING MERGE, AND STARTING WITH TWP I ENSURE THAT THAT PRIORITY IS PRESERVED
********************************************************************************/
merge 1:1 turbinemanufacturer turbinemodel using "`powercurves'", nogen

merge 1:1 turbinemanufacturer turbinemodel using "`joern_curves'", nogen

***************************************************
* STANDARDIZE AND DEAL WITH ADDITIONAL DUPLICATES
***************************************************
foreach manu in alizeo liberty {
	replace turbinemodel = subinstr(turbinemodel, "`manu'", "", 1)
}
replace turbinemodel = trim(turbinemodel)

replace turbinemanufacturer = "awp" if turbinemanufacturer == "awp3.6(grid"
replace turbinemanufacturer = "future_energy" if inlist(turbinemanufacturer, "future", "futurenergy")
replace turbinemanufacturer = "northern power systems" if turbinemanufacturer == "northern"

replace turbinemanufacturer = "windenergy lebanon" if turbinemanufacturer == "windenergylebanon"

replace turbinemanufacturer = "northern power systems" if turbinemanufacturer == "northern power"

* MODEL NAMES
replace turbinemodel = "b82" if turbinemodel == "82.4m 2.3mw"

*Mitsubishi
replace turbinemodel = "mwt-62-1000" if regexm(turbinemodel, "mwt62") & turbinemanufacturer == "mitsubishi"
replace turbinemodel = "mwt-92-2.4" if regexm(turbinemodel, "mwt92-2.4") & turbinemanufacturer == "mitsubishi"
replace turbinemodel = "mwt-95-2.4" if regexm(turbinemodel, "mwt95-2.4") & turbinemanufacturer == "mitsubishi"
replace turbinemodel = "mwt-1000" if regexm(turbinemodel, "mwt-1000 ") & turbinemanufacturer == "mitsubishi"
replace turbinemodel = "mwt-1000a" if regexm(turbinemodel, "mwt-1000a") & turbinemanufacturer == "mitsubishi"

rename turbinemodel powercurve_turbinemodel

* CREATE CAPACITY AS MAX VALUE FROM WIND
egen powercurve_max_cap = rowmax(w*)

ren (w0-w30) ///
    (w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 ///
     w22 w23 w24 w25 w26 w27 w28 w29 w30 w31 w32 w33 w34 w35 w36 w37 w38 w39 ///
	 w40 w41 w42 w43 w44 w45 w46 w47 w48 w49 w50 w51 w52 w53 w54 w55 w56 w57 ///
	 w58 w59 w60)

label var powercurve_max_cap "Capacity(kW) calculated by us as max value in power curve data"
order turbinemanufacturer powercurve_turbinemodel powercurve_max_cap w*
sort turbinemanufacturer powercurve_turbinemodel
save "$generated_data/power_curve.dta", replace
********************************************************************************
tempsetup
capture log close
exit
