*GET PRICES AND SHARES FROM EIA DATA
egen tk = rowtotal(retailsales salesforresale)
gen share_retail = retailsales / tk
drop tk

gen price_resale_EIA = revenuefromresale/ salesforresale*1000
label var price_resale "Avg. Resale Price EIA (Annual, $/MWh)"
label var salesforresale "Annual sales for resale (MWh?)"

* create generation date variables using EIA-923 data
gen ymdate = ym(year,month)
format ymdate %tm

*AFTER LEADING ZEROS ARE DROPPED, REPLACING MISSINGS WITH ZEROS
replace netgen = 0 if netgen == .
gen te = ymdate if netgen != 0
egen td =  min(te), by(facilityid)
gen first_gen_date = ym(year(dofm(td)),month(dofm(td)))
format first_gen_date %tm

gen first_gen_year = year(dofm(first_gen_date))
drop if ymdate < first_gen_date & netgen == 0

drop td

* generate age variables (age and age^2)
gen age = ymdate - first_gen_date 
forval i = 1/2 {
	gen age_`i' = age^`i'
}
lab var age_1 "Age (months)"
lab var age_2 "Age$^2$ (months)"

* generate average turbine size variable
gen turbsize = nameplate_capacity / turbine_num

gen reg_dummy = .
replace reg_dummy=0 if regulatory_status=="NR"
replace reg_dummy=1 if regulatory_status=="RE"

* compute capacity factor
gen dayspermonth=.
replace dayspermonth=31 if inlist(month,1,3,5,7,8,10,12)
replace dayspermonth=30 if inlist(month,4,6,9,11)
replace dayspermonth=28 if month==2
replace dayspermonth=29 if month==2 & mod(year,4)==0
gen hoursperday = 24
gen monthcap = dayspermonth*hoursperday*nameplate_capacity
label var monthcap "denominator of capacity factor"
gen capacity_factor = netgen/(monthcap)

gen inferredcapacity = powercurve_max_cap
*create potential output variables from the wind power curves and wind data
gen turbine_capacity_pc = inferredcapacity /1000
lab var turbine_capacity_pc "capacity of turbine used in powercurve matching (MW)"

gen ptnl_cf = output/(dayspermonth*hoursperday*turbine_capacity_pc)*100 
gen ptnl_cf_adj = output_adjusted/(dayspermonth*hoursperday*turbine_capacity_pc)*100 
gen ptnl_output = monthcap*ptnl_cf/100
gen ptnl_output_adj = monthcap*ptnl_cf_adj/100

lab var ptnl_cf 		"Potential capacity factor from wind data and power curve"
lab var ptnl_cf_adj 	"Potential capacity factor from wind data and power curve (adjusted for pressure and temperature)"
lab var ptnl_output 	"Potential output from wind data and power curve"
lab var ptnl_output_adj "Potential output from wind data and power curve (adjusted for pressure and temperature)"

gen ptnl_cf_refturb = output_refturb/(dayspermonth*hoursperday*reference_turbine_capacity)*100
gen ptnl_cf_adj_refturb = output_refturb_adjusted/(dayspermonth*hoursperday*reference_turbine_capacity)*100
gen ptnl_output_refturb = monthcap*ptnl_cf_refturb/100
gen ptnl_output_adj_refturb = monthcap*ptnl_cf_adj_refturb/100

lab var ptnl_cf_refturb 		"Reference turbine potential capacity factor from wind data and power curve"
lab var ptnl_cf_adj_refturb 	"Reference turbine potential capacity factor from wind data and power curve (adjusted for pressure and temperature)"
lab var ptnl_output_refturb 	"Reference turbine potential output from wind data and power curve"
lab var ptnl_output_adj_refturb "Reference turbine potential output from wind data and power curve (adjusted for pressure and temperature)"

rename wind2 wind_speed2
rename wind3 wind_speed3

lab var wind_speed "Wind Speed (m/s)"
lab var wind_speed2 "Wind Speed Squared"
lab var wind_speed3 "Wind Speed Cubed"
lab var windvar "Var(Wind Speed)"
lab var temperature "Temperature (K)"
lab var tempwindcov "Cov(Wind Speed, Temperature)"
replace airpressure = airpressure/101325 // convert from pascals to atmospheres
lab var airpressure "Air Pressure (atm)"
replace airwindcov = airwindcov/101325 // convert from pascals to atmospheres
lab var airwindcov "Cov(Wind Speed, Pressure)"
lab var num_wind_hours "Number of hours with wind speed data this month"

drop dayspermonth hoursperday

* generate log transformations
gen log_netgen = log(netgen)

gen log_nameplate = log(nameplate)
gen log_turbines = log(turbine_num)

gen log_ptnl = log(ptnl_output)
gen log_ptnl_adj = log(ptnl_output_adj)
gen log_ptnl_refturb = log(ptnl_output_refturb)
gen log_ptnl_adj_refturb = log(ptnl_output_adj_refturb)



* relabel variables
lab var nameplate "Nameplate Capacity"
lab var log_nameplate "log(Capacity)"
lab var netgen "Generation"
lab var log_netgen "log(Generation)"
lab var capacity_factor "Capacity Factor"
lab var turbine_num "No. Turbines (EIA)"
lab var turbsize "Turbine Size (MW) - imputed"
lab var reg_dummy "Regulated"
lab var state "State"
lab var first_gen_date "First Generation Date (EIA 923)"
lab var first_gen_year "First Generation Year (EIA 923)"
label var log_turbines "log(Turbines)"
label var log_nameplate "log(Capacity)"

drop te
