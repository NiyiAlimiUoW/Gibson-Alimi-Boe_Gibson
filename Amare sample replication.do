global Root ""
global Data "${Root}\Data"
global Log "${Root}\Log"
global Output "${Root}\Output"
global Raw "${Root}\Raw"
global DHS2013 "${Raw}\DHS 2013-data"
global DHS2008 "${Raw}\DHS 2008-data"

global Do "${Root}\Do"
cd  "${Root}\Data"


import dbase using "${DHS2013}\NGGE6AFL\NGGE6AFL.dbf", clear case(lower) // DHS cluster information from DHS dataset
save "${Raw}\DHS2013_cluster_info.dta", replace

import dbase using "${DHS2008}\NGGE52FL\NGGE52FL.dbf", clear case(lower) // DHS cluster information from DHS dataset
save "${Raw}\DHS2008_cluster_info.dta", replace


use "${Raw}\DHS2008_cluster_info.dta", clear
rename (dhsclust latnum longnum) (dhsclust08 latnum08 longnum08)

geonear dhsclust08 latnum08 longnum08 using "${Raw}\DHS2013_cluster_info.dta", n(dhsclust latnum longnum) within(11) near(0) long
sort dhsclust km_ 

keep if km_ <=10 //

contract dhsclust //482 clusters within 10km while Amare reports 560 clusters

drop _freq
/*
gen within_10km = 1
gen v001= dhsclust

merge 1:m v001 using "${Data}\OA_2013_full_cluster_DMSP_VIIRS_base.dta"

keep if _merge==3 //Number of observations is 11, 164 in clusters that are within 10km rather than 15,006 reported in Amare.

*/


//Finding Distance between 2008 clusters and 2013 clusters
use "${Raw}\DHS2013_cluster_info.dta", clear
rename (dhsclust latnum longnum) (dhsclust13 latnum13 longnum13)

geonear dhsclust13 latnum13 longnum13 using "${Raw}\DHS2008_cluster_info.dta", n(dhsclust latnum longnum) within(11) near(0) long
sort dhsclust km_ 

keep if km_ <=10 //

contract dhsclust //478 clusters within 10km while Amare reports 560 clusters

drop _freq

/*
gen within_10km = 1
gen v001= dhsclust
merge 1:m v001 using "${Data}\OA_2008_full_cluster_DMSP_base.dta"


keep if _merge==3 //Number of observations is 8, 812 in clusters that are within 10km rather than 15,006 reported in Amare.

*/
stop