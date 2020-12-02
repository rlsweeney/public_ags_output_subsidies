/* GET NEGATIVE PRICES BY HOUR ISO TO COMPARE TO CALLAWAY PAPER
Description: This file calculates fraction of negative prices by
iso-month-hour of day
********************************************************************************/
local fname negative_lmp_hourofday

clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)
do "$repodir/code/setup.do"

tempsetup

capture log close
log using "$outdir/logs/`fname'.txt", replace text
********************************************************************************

global lmp_data "$dropbox/Data/public/ISO_LMP"
global output "$repodir/generated_data"

********************************************************************************
*		CALC FRACTION OF YEAR-MONTH-HOUR OF DAY WITH NEGATIVE PRICES 
********************************************************************************
/* This program calculate the fraction of negative prices for each year-month-hour of day
   combo.
   
   The final output will give 
   year   month   hour      fract_below_0
   2009    12      2            .5
   
   This says that 2AM in December 2009, 50% of prices were below 0

*/
capture program drop hour_fractions
program define hour_fractions
	qui {
		gen month = month(date)
		gen year = year(date)
		*Make sure there is only a single year
		qui tab year
		assert `r(r)' == 1
		
		* Calculate Fraction of prices below 0 for year-month-hour of day
		bys year month hour: gen total_obs = _N
		bys year month hour: egen count_below_0 = total(lmp < 0)
		gen fract_below_0 = count_below_0 / total_obs
		
		keep month year hour fract_below_0
		bys month year hour: keep if _n == 1
	}	
end

global firstyear 2010
global lastyear 2014

***********************
* PJM - Hours 1-24
**********************
forval year = $firstyear / $lastyear {
	qui {
		use "$lmp_data/PJM/pjm_`year'.dta", clear
		hour_fractions
		tempfile pjm_`year'
		save "`pjm_`year''"
	}
}
clear
forval year = $firstyear / $lastyear {
	append using "`pjm_`year''"
}
gen iso = "PJM"
compress
tempfile pjm
save "`pjm'"
*************************
* ERCOT - Hours 0 - 23
************************
forval year = $firstyear / $lastyear { 
	use "$lmp_data/ERCOT/ercot_`year'.dta", clear
	hour_fractions
	* Change from 0-23 to 1-24
	replace hour = hour + 1
	tempfile ercot_`year'
	save "`ercot_`year''"	
}
clear
forval year = $firstyear / $lastyear {
	append using "`ercot_`year''"
}
gen iso = "ERCOT"
compress
tempfile ercot
save "`ercot'"
***********************
* MISO - Hours 0 - 23
***********************
forval year = $firstyear / $lastyear {
	use "$lmp_data/MISO/miso_`year'.dta", clear
	hour_fractions
	* Change from 0 - 23 to 1 -24
	replace hour = hour + 1
	tempfile miso_`year'
	save "`miso_`year''"
}
clear
forval year = $firstyear / $lastyear {
	append using "`miso_`year''"
}
gen iso = "MISO"
order year month hour
compress
tempfile miso
save "`miso'"
******************************
* NEISO - hours 1 - 25
******************************
forval year = $firstyear / $lastyear {
	qui {
		use "$lmp_data/NEISO/neiso_lmp_`year'.dta", clear
		hour_fractions
		tempfile neiso_`year'
		save "`neiso_`year''"
	}
}
clear
forval year = $firstyear / $lastyear {
	append using "`neiso_`year''"
}
gen iso = "NEISO"
compress
tempfile neiso
save "`neiso'"
************************
* NYISO - Hours 0 - 23
************************
forval year = $firstyear / $lastyear {
	qui {
		use "$lmp_data/NYISO/nyiso_`year'.dta", clear
		hour_fractions
		
		* Change from 0 - 23 to 1 - 24
		replace hour = hour + 1
		tempfile nyiso_`year'
		save "`nyiso_`year''"
	}
}
clear
forval year = $firstyear / $lastyear {
	append using "`nyiso_`year''"
}
gen iso = "NYISO"
compress
tempfile nyiso
save "`nyiso'"
*******************************
* CAISO - Hours 1 - 25
*******************************
forval year = $firstyear / $lastyear {
	qui {
		use "$lmp_data/CAISO/caiso`year'.dta", clear
		hour_fractions
		tempfile caiso_`year'
		save "`caiso_`year''"
	}
}
clear
forval year = $firstyear / $lastyear {
	append using "`caiso_`year''"
}
gen iso = "CAISO"
compress
tempfile caiso
save "`caiso'"		
***************************
* BRING THEM ALL TOGETHER
***************************
clear
foreach iso in ercot miso neiso nyiso pjm caiso {
	append using "``iso''"
}
compress
save "$output/lmp_hour_of_day_fractions.dta", replace


********************************************************************************
tempsetup
capture log close
exit
