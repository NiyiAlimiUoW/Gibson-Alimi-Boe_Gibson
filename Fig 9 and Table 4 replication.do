
/* This do file replicates the results presented in Figure 9 and Table 4
Before you start, please apply to DHS for microdata access and then download the Nigerian DHS Data from the DHS program including the geography files in the GE folders (remember that you cannot redistribute the DHS micro data).
*/

*Stata version 18.5
*set maxvar 120000 

********************************************************************************
*This section cleans the DHS data
********************************************************************************
clear

*************Setting up environment variable *************
global Root ""  //change root to where downloaded files is stored in your computer

/* Run only once to create directory
mkdir "${Root}\Data"
mkdir "${Root}\Log"
mkdir "${Root}\Output"
*/


global Data      "${Root}\Data"
global Log       "${Root}\Log"
global Output    "${Root}\Output"
global Raw       "${Root}\Raw"
global DHS2013   "${Raw}\DHS 2013-data" //Location of 2013 DHS Data. Download all files including geography files
global DHS2008   "${Raw}\DHS 2008-data" //Location of 2008 DHS Data. Download all files including geography files

cd  "${Root}\Data"

//log files
capture log close
log using "${Log}\replicate.txt", replace

	*--------------------------------------------------------------------------*
	*2013 DHS  Data cleaning
	*--------------------------------------------------------------------------*
	use  "${DHS2013}\NGIR6ADT\NGIR6AFL", clear //Use Mothers recode

	gen weight=v005/1000000

	keep caseid midx_* v000 v001 v002 v003 v004 v005 v006 v007 v008 v009 v010 v011 v012 v013 v014 v015 v016 v017 v018 v019 v019a v020 v021 v022 v023 v024 v025 v026 v027 v028 v030 v031 v032 v034 v040 v042 v044 v101 v102 v103 v104 v105 v106 v107 v113 v115 v116 v119 v120 v121 v122 v123 v124 v125 v127 v128 v129 v130 v131 v133 v134 v135 v136 v137 v138 v139 v140 v141 v149 v150 v151 v152 v153 v190 v191 v212  v157 v393 v729 v701 v702 v715 awfactt awfactu awfactr awfacte awfactw v155 v191 ml101 v201 hw5_* hw8_* hw11_* b4_* b5_* hw1_* hw70_* hw71_* hw72_* bord_* weight

	rename (b4_01 b4_02 b4_03 b4_04 b4_05 b4_06 b4_07 b4_08 b4_09) (b4_1 b4_2 b4_3 b4_4 b4_5 b4_6 b4_7 b4_8 b4_9) //sex of child
	rename (b5_01 b5_02 b5_03 b5_04 b5_05 b5_06 b5_07 b5_08 b5_09) (b5_1 b5_2 b5_3 b5_4 b5_5 b5_6 b5_7 b5_8 b5_9) //child is alive
	rename (bord_01 bord_02 bord_03 bord_04 bord_05 bord_06 bord_07 bord_08 bord_09) (bord_1 bord_2 bord_3 bord_4 bord_5 bord_6 bord_7 bord_8 bord_9) //birth order
	reshape long midx_ bord_ hw1_ b5_ hw70_ hw71_ hw72_ hw5_ hw8_ hw11_ b4_, i(caseid) j(child_num)

	order midx_ b5_ hw1_ hw70_ hw71_ hw72_ hw5_ hw8_ hw11_, after(v004)

	tab v135, miss
	keep if v135==1 //usual resident

	drop if midx_==. //not children
	rename midx_ midx
	keep if b5_ ==1 //child is alive


	drop if  hw70 >= 9996  //Missing New WHO standard HAZ, WHZ and WAZ 
	drop if hw70==. //Missing New WHO standard HAZ, WHZ and WAZ 

	//Generating outcome variables
	gen HAZ = hw70_/100
	gen WAZ= hw71_/100
	gen WHZ = hw72_/100
	gen stunted = cond(HAZ<-2,1,0)
	gen wasted = cond(WHZ<-2,1,0)
	gen underweight = cond(WAZ<-2,1,0)

	numlabel, add

	//boy child
	tab b4_, miss
	gen boy_child = cond(b4_==1,1,0)

	//age of child
	tab hw1_, miss
	gen age_of_child = hw1_
	
	//age of child squared
	gen age_of_child_sq = age_of_child^2

	//birth order
	tab bord, miss
	gen birth_order = bord

	//mother education in single years
	tab v133,miss
	gen mother_edu = v133
	replace mother_edu =. if mother_edu==99

	//age of mother at first birth
	tab v212, miss
	gen age_mother_first = v212

	//Woman's partner's education. It may be different from child father's education
	tab v715, miss
	clonevar father_edu = v715 //Partner edu in single years
	replace father_edu =. if inlist(father_edu,98,99) 

	//Wealth quintile
	tab v190, miss
	tab v190, gen(wlth_q_)

	//Household has TV
	tab v121, miss
	clonevar has_tv =v121
	replace has_tv=. if has_tv==9

	//Woman reads newspaper (0/1)
	tab v157, miss
	clonevar reads_newspaper =v157
	tab reads_newspaper
	replace reads_newspaper=. if reads_newspaper==9
	replace reads_newspaper=1 if inlist(reads_newspaper,1,2)

	//Woman visited  family planning worker in the last 12 months
	tab v393, miss
	clonevar visit_family_planning = v393
	replace visit_family_planning=. if visit_family_planning==9

	summ HAZ stunted WHZ wasted WAZ underweight boy_child age_of_child age_of_child_sq birth_order mother_edu age_mother_first father_edu  wlth_q_* has_tv reads_newspaper visit_family_planning 

	save "${Data}\OA_2013_full_cluster.dta", replace

*-----------------------------------------------------------------------------*
*Merge with 2013 DMSP Night lights
*-----------------------------------------------------------------------------*	
	use "${Data}\OA_2013_full_cluster.dta", clear
	gen dhsclust = v001

	//Merge with cluster geography files
		preserve
		import dbase using "${DHS2013}\NGGE6AFL\NGGE6AFL.dbf", clear case(lower) //use geography file from DHS data
		save "${Raw}\DHS2013_cluster_info.dta", replace
		restore

	mmerge dhsclust using "${Raw}\DHS2013_cluster_info.dta", type(n:1) ukeep(latnum longnum urban_rura) //merge with latnum and longnum from geography file
	tab _merge
	drop if _merge==2 //drop one cluster (cluster 226) that does not have any kids in it

	****************Merge with DMSP Night lights****************************
		preserve
		import dbase using "${Raw}\2013_DMSP_DN_2013DHS.dbf", clear case(lower)
		rename dhsclust dhsclust13
		save "${Raw}\2013_DMSP_DN_2013DHS.dta", replace
		restore

	rename dhsclust dhsclust13
	mmerge dhsclust13 using "${Raw}\2013_DMSP_DN_2013DHS.dta",  type(n:1) ukeep(rastervalu) urename(rastervalu DMSP_point)  // keeping DMSP point value

	tab dhsclust if _merge==1 // DHS clusters 302,373,422,514,557,569, 639 are missing latitude and longitude infomation. This is missing from original DHS data, so no lights for them
	tab dhsclus latnum if _merge==1

	keep if _merge==3 //Exclude those with missing lat and long & one cluster with no kids

	//Creating Log of DMSP
	foreach var in DMSP_point {
	gen l_`var' = ln(`var')
	replace l_`var'=0 if l_`var'==. // dealing with zero lights. 
	}

	//Saving 2013 DHS and DMSP light
	save "${Data}\OA_2013_full_cluster_DMSP_base.dta", replace //2013 DHS data


/*******************************************************VIIRS*****************************************************
************************************************DHS 2km for urban and 5km for rural******************
******************************MASKED and Scaled******************************************************/
* Download Night lights data
Sample code for cleaning night lights 
		preserve
		foreach b in 2km 5km {
		*local b 5km
		foreach mm in 01 02 03 04 05 06 07 08 09 10 11 12{
		*local mm 01
		import dbase using "${Raw}\ToNiyi_Monthly_2015AnnualMask\ZStatALL_VIIRS_NGA_2013DHS_`b'_2013`mm'01_Monthly_Mask_2015.dbf", clear case(lower)
		gen dhsclust = substr(dhsid,-3,.), after(dhsid)
		destring dhsclust, replace
		keep dhsclust mean max
		replace mean =. if mean <=0
		replace max =. if max <=0

		rename mean  mean_viirs_m_`b'_`mm'
		rename max  max_viirs_m_`b'_`mm'

		tempfile  viirs_m_`b'_`mm'
		save `viirs_m_`b'_`mm'', replace
		}

		local mm 01
		use `viirs_m_`b'_`mm'', clear
		foreach mm in 02 03 04 05 06 07 08 09 10 11 12{
		qui merge 1:1 dhsclust using `viirs_m_`b'_`mm'', keepusing(mean_viirs_m_`b'_`mm' max_viirs_m_`b'_`mm')
		drop _merge
		}


		egen miss_cluster = rowmiss(mean_viirs_m_`b'_*)
		tab miss_cluster
		summ mean_viirs_m_*

		egen mean_annual_viirs_m_`b' = rowtotal(mean_viirs_m_`b'_*)
		egen max_annual_viirs_m_`b' = rowtotal(max_viirs_m_`b'_*)

		gen mean_annual_viirs_m_`b'_scaled =.
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*1 if miss_cluster==0
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*(12/11) if miss_cluster==1
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*(12/10) if miss_cluster==2
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*(12/9) if miss_cluster==3
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*(12/8) if miss_cluster==4
		replace mean_annual_viirs_m_`b'_scaled= mean_annual_viirs_m_`b'*(12/7) if miss_cluster==5

		save "${Data}\viirs_masked_`b'.dta", replace
		}
		restore

drop _merge
rename dhsclust13 dhsclust

foreach b in 2km 5km {
merge m:1 dhsclust using  "${Data}\viirs_masked_`b'.dta", keepusing(mean_annual_viirs_m_`b' mean_annual_viirs_m_`b'_scaled max_annual_viirs_m_`b')
drop _merge
}

foreach var in mean_annual_viirs_m_2km mean_annual_viirs_m_2km_scaled max_annual_viirs_m_2km mean_annual_viirs_m_5km mean_annual_viirs_m_5km_scaled max_annual_viirs_m_5km{
replace `var' = 0 if `var'==.
}



gen mean_viirs_m_scaled_DHS=.
replace mean_viirs_m_scaled_DHS= mean_annual_viirs_m_2km_scaled if urban_rura=="U"
replace mean_viirs_m_scaled_DHS= mean_annual_viirs_m_5km_scaled if urban_rura=="R"


summ   mean_viirs_m_scaled_DHS 

drop if child_num ==.
save "${Data}\OA_2013_full_cluster_DMSP_VIIRS_base.dta", replace

*Replication of Figure 9
use "${Data}\OA_2013_full_cluster_DMSP_VIIRS_base.dta", clear //base data
rename ( mean_viirs_m_scaled_DHS ) ( mean_viirs_m_scaled )


foreach var in mean_viirs_m_scaled {
gen l_`var'= ln(`var')
replace l_`var'= 0 if l_`var'==.
}

*replace cluster with 0.82 ( negative log viirs to zero)
summ l_mean_viirs_m_scaled, d
count if l_mean_viirs_m_scaled<0
replace l_mean_viirs_m_scaled=0 if l_mean_viirs_m_scaled<0

*-----------------------------------------------------------------------------*
*This section replicates the numbers in Fig 9 and Table 4
*-----------------------------------------------------------------------------*

local sample l_DMSP_point, l_mean_viirs_m_scaled,boy_child, age_of_child, birth_order, mother_edu, age_mother_first, father_edu,  v190, has_tv, reads_newspaper, visit_family_planning
keep if !missing(`sample')
local controls boy_child, age_of_child, birth_order, mother_edu, age_mother_first, father_edu, v190, has_tv, reads_newspaper, visit_family_planning 
summ l_DMSP_point   l_mean_viirs_m_scaled 
foreach var in l_DMSP_point  l_mean_viirs_m_scaled {
summ `var' if !missing(`controls') 
gen `var'_c = `var'-r(mean)
}
summ l_DMSP_point_c  l_mean_viirs_m_scaled_c 



foreach var in l_DMSP_point_c  l_mean_viirs_m_scaled_c  {
gen `var'_sq = (`var')^2 
gen `var'_cb = (`var')^3
gen `var'_qd = (`var')^4
}



local controls boy_child age_of_child birth_order mother_edu age_mother_first father_edu  ib1.v190 has_tv reads_newspaper visit_family_planning 
global regopts se bra

local apprep replace
foreach light in  l_DMSP_point_c  l_mean_viirs_m_scaled_c {
*local apprep replace
foreach var in HAZ  WHZ WAZ {
*local apprep replace

*local light l_DMSP_point_c
*local var HAZ


*linear and sq and cube and quad
regress `var' `light' c.`light'#c.`light' c.`light'#c.`light'#c.`light' c.`light'#c.`light'#c.`light'#c.`light'  `controls'[w=weight] , cluster(dhsclust)

margins, dydx(*)
matlist r(table)
local margins = r(table)[1,1]
local margins_se = r(table)[2,1]
local margins_p = r(table)[4,1]

outreg2 using "${Output}\Fig9_sustain.out", keep(`light' c.`light'#c.`light' c.`light'#c.`light'#c.`light' c.`light'#c.`light'#c.`light'#c.`light') `apprep' ${regopts} dec(4) ctitle(`var'_`light') addtext(Child and parental characteristics, Yes) addstat( Margins(dy/dx), `margins', Margins(se), `margins_se', Margins(p-value), `margins_p' )
local apprep append

outreg2 using "${Output}\Fig9_sustain_fl.out", `apprep' ${regopts} dec(4) ctitle(`var'_`light') addtext(Child and parental characteristics, Yes) addstat(Margins(dy/dx), `margins', Margins(se), `margins_se', Margins(p-value), `margins_p' )

local apprep append

}
}


*--------------------------------------------*
/* Table 4 */
*--------------------------------------------*
global regopts se bra
local apprep replace
foreach var in HAZ WHZ WAZ{
foreach light in l_DMSP_point_c l_mean_viirs_m_scaled_c {
npregress kernel `var' `light' i.boy_child age_of_child birth_order mother_edu age_mother_first father_edu  ib1.v190 i.has_tv i.reads_newspaper i.visit_family_planning , kernel(epan) vce(bootstrap, reps(100) seed(123))
outreg2 using "${Output}\Table4_sustain.out", `apprep' ${regopts} dec(4) ctitle(`var') addtext(Child and parental characteristics, Yes)
local apprep append
}

}

stop