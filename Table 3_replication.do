*Stata version 18.5
clear

*************Setting up environment variable *************
*global Root ""  //change root to where downloaded files is stored in your computer

use "${Root}\Table3_replication_data.dta" , clear

gen loglight2012=ln(light2012)
reghdfe loglight2012 elev0_9, absorb(country) vce(cluster country)
keep if e(sample)==1

**	generate ihs for all lights variables

for var dmsp2012 bm_nn bm_allangle : gen ihsX=ln(X + sqrt(X^2+1))

**	redo columns (i) to (iii) 
*column i
reghdfe ihsdmsp2012 elev0_9, absorb(country) vce(cluster country)
outreg2 using "${Root}\Table3", excel replace se dec(2) 

**	get the mean-reversion parameter
*column ii
reghdfe ihsdmsp2012 ihsbm_nn, absorb(country) vce(cluster country)
test ihsbm_nn==1
outreg2 using "${Root}\Table3", excel append se dec(2) 

*Column iii
reghdfe ihsbm_nn elev0_9, absorb(country) vce(cluster country)
outreg2 using "${Root}\Table3",  excel append se dec(2) 


stop


