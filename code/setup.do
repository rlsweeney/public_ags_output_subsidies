clear
set more off, permanently
set matsize 1000
*set scheme s1mono
set scheme s1color
set seed 123456

********************************************************************************
* SET PATHS
********************************************************************************
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/paths.do"

global outdir "$repodir/output" // MAY BE USEFUL TO REDIRECT FOR COMPARISONS/ ROBUSTNESS ETC 

global generated_data "$dropbox/generated_data"
** can uncomment this if you want to run build code and updated right to the repo
** but these are very slow. alternatively, `move_files.do` copies files run to the repo
global generated_data "$repodir/generated_data" 

capture mkdir "$repodir/temp"
capture mkdir "$repodir/output/estimates"

********************************************************************************
* DEFINE PROGRAMS
********************************************************************************
*THIS PROGRAM CD'S TO THE TEMP DIRECTORY AND CLEARS IT
capture program drop tempsetup
program define tempsetup

	cd "$repodir/temp"
	local list : dir . files *
	foreach f of local list {
		erase "`f'"
	}
end 


*THIS PROGRAM KILLS THE TEMP DIRECTORY
capture program drop tempclose
program define tempclose
	pause
	clear
	cd "$repodir/temp"
	local list : dir . files *
	foreach f of local list {
		erase "`f'"
	}
	cd "$repodir"
	rmdir "$repodir/temp"
end 
exit 

********************************************************************************
* INSTALL USER-WRITTEN PACKAGES MANUALLY AS NEEDED
********************************************************************************
ssc install tabout
ssc install coefplot
ssc install estout
ssc install ivreg2
ssc install ranktest
ssc install spmap
ssc install shp2dta
ssc install mif2dta
ssc install geonear
ssc install egenmore
ssc install outreg
ssc install carryforward
ssc install dropmiss /*superseded*/
ssc install statastates
ssc install unique 
ssc install num2words
ssc install cem

net install grc1leg

*note, this relies on a since supercede stata command, renvars. 
* type search renvars to install manually
