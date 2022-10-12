/* RUN ALL OF THE BUILD DO FILES */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************
global manu_dir "$repodir/manuscript"

* TABLES
global dir "$repodir/output/tables"

local file: dir "$dir" files "*"

foreach f of local file{
    copy "$dir/`f'"  "$manu_dir/`f'", replace
}				

*FIGURES 
global dir "$repodir/output/figures"

local file: dir "$dir" files "*"

foreach f of local file{
    copy "$dir/`f'"  "$manu_dir/`f'", replace
}				

*ESTIMATES 
global dir "$repodir/output/estimates"

local file: dir "$dir" files "*"

foreach f of local file{
    copy "$dir/`f'"  "$manu_dir/`f'", replace
}				
