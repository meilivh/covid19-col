/*************************************
*Created: 04/23/2020
*Last Modified: 05/06/2020
*Purpose: 		
	- Create working datasets at national and department level. 
*Author: Lina Ramirez 
*Created files: 
	-"C:\Users/linar\Dropbox\Personal-Projects\Covid-Colombiadata\ins_mod\departamentos\data_dpto.dta"
	-"C:\Users/linar\Dropbox\Personal-Projects\Covid-Colombiadata\ins_mod\nacional\data_nal.dta"

*READ THIS: 
*Requirements: STATA 16. 	
*Files needed: INS_D_M_Y.csv and Pruebas_D_M_Y.csv Camas_D_M_Y (the last update of Camas available)
*Change dates in lines 41 and 43 to generate new csv for each day
*Run only ONCE per day of interest otherwise eliminate duplicate observations. 
	
*************************************/


*Setting paths 
clear all

gl path "C:\Users/linar\Dropbox\Personal-Projects\Covid-Colombia"
gl do "C:\Users/linar\Desktop\GitHub\covid19\stata"
	

gl data "$path\data"
gl raw "$data\ins_raw"
gl mod "$data\ins_mod"

cd ${raw}

/*
		Cleaning dataset 	
*/

*import delimited codigo_dpto.csv, encoding(utf8) clear
*save codigo_dpto.dta, replace 

*import delimited poblacion_dptos.csv, encoding(utf8) clear  
*rename depto departamento 
*merge 1:1 departamento using codigo_dpto.dta 
*rename pob_censo_2018 poblacion
*drop _merge 
*save poblacion_dptos.dta, replace

*Local determining the day of update INS 
local i=9
*Local determining the day of update Pruebas
local p=6
*Local determining the last update of Camas. 
local j=1
*Month 
local m=5
*Dataset imported to check false positives - May 2. 
local f=2

import delimited Pruebas_`p'_0`m'_2020.csv, encoding(utf8) clear 
save Pruebas.dta, replace 

import delimited Camas_`j'_0`m'_2020.csv, encoding(utf8) clear 
drop departamento 
save Camas.dta, replace

import delimited INS_`i'_0`m'_2020.csv, encoding(utf8) clear

*Falsos confirmados: 
gen falso_positivo=1 if codigodivipola==-1
replace falso_positivo=0 if falso_positivo==. 
label define fp 1 "F POSITIVO" 0 "V POSITIVO"
label values falso_positivo fp 
egen fp=total(falso_positivo)
*Previous false positives
local fp_old=40
local fp=fp

display "*********************************NEW FALSE POSITIVES= `fp'**************************"

/*			RUN IF THERE ARE NEW FALSE POSITIVES 
preserve 
keep if falso_positivo==1 
keep iddecaso falso_positivo 
save temp.dta, replace
display "Importing INS_`f'_0`m'_2020.csv"
import delimited INS_`f'_0`m'_2020.csv, encoding(utf8) clear
merge m:1 iddecaso using temp.dta 
keep if _merge==3 
drop _merge 
gen fecha="`i'-0`m'-2020"
order fecha, first
sort fecha
gen fecha1 = date(fecha,"DMY")
format fecha1 %tdNN/DD/CCYY
order fecha1, after(fecha)
drop fecha 
rename fecha1 fecha 
rename departamentoodistrito departamento
replace departamento=subinstr(departamento, "á", "a",.)
replace departamento=subinstr(departamento, "é", "e",.)
replace departamento=subinstr(departamento, "í", "i",.)
replace departamento=subinstr(departamento, "ó", "o",.)
replace departamento=subinstr(departamento, "ú", "u",.)
replace departamento=ustrupper(departamento)
keep iddecaso departamento fecha 
egen false_positive=count(iddecaso), by(departamento fecha)
collapse fecha false_positive, by(departamento)
save false_positives_dpto.dta, replace
collapse (sum) false_positive, by(fecha)
save false_positives_nal.dta, replace  
erase temp.dta 
restore 
*/

*fixing ciudad 
rename ciudaddeubicación ciudad 

replace ciudad=subinstr(ciudad, "á", "a",.)
replace ciudad=subinstr(ciudad, "é", "e",.)
replace ciudad=subinstr(ciudad, "í", "i",.)
replace ciudad=subinstr(ciudad, "ó", "o",.)
replace ciudad=subinstr(ciudad, "ú", "u",.)
replace ciudad=ustrupper(ciudad)


*fixing departamento
rename departamentoodistrito departamento

replace departamento=subinstr(departamento, "á", "a",.)
replace departamento=subinstr(departamento, "é", "e",.)
replace departamento=subinstr(departamento, "í", "i",.)
replace departamento=subinstr(departamento, "ó", "o",.)
replace departamento=subinstr(departamento, "ú", "u",.)
replace departamento=ustrupper(departamento)

replace departamento="ATLANTICO" if departamento=="BARRANQUILLA D.E."
replace departamento="CHOCO" if departamento=="BUENAVENTURA D.E."
replace departamento="BOLIVAR" if departamento=="CARTAGENA D.T. Y C."
replace departamento="MAGDALENA" if departamento=="SANTA MARTA D.T. Y C." 


*merge with codigo 
merge m:1 departamento using codigo_dpto

*Eliminating false positives: 
keep if _merge!=1 
drop _merge 
order codigo, after(departamento)

*merge with poblacion
merge m:1 codigo using poblacion_dptos
order poblacion, after(codigo) 
drop _merge 

*merge with pruebas 
merge m:1 codigo using Pruebas
drop _merge 

erase Pruebas.dta

*merge with camas 
merge m:1 codigo using Camas 
drop _merge 

erase Camas.dta

*merge with poblacion por departamento 


*time variables
local vars "fechadenotificación fis fechademuerte fechadiagnostico fecharecuperado fechareporteweb"
foreach var in `vars'{
capture split `var', p(T)
capture drop `var'2 
capture order `var'1, after(`var')
capture drop `var'
capture gen `var'=date(`var'1, "YMD")
capture format `var' %td 
capture order `var', after(`var'1)
capture drop `var'1 
}

*cap letters 
local vars "atención sexo tipo estado"
foreach var in `vars'{
replace `var'=ustrupper(`var')
}



*tostring codigo 
tostring codigo, gen(codigostr)
replace codigostr="0"+codigostr if codigo<10 




/*
			Generating variables 	
*/


*Sintomas
gen tipo_sintomas=0 if fis!=. 
replace tipo_sintomas=1 if fis==. 
label define sintomas 0 "SINTOMATICO" 1 "ASINTOMATICO"
label values tipo_sintomas sintomas 

*Tiempo entre notificacion y diagnostico 
gen tiempo_prueba=fechadiagnostico-fechadenotificación
label var tiempo_prueba "tiempo entre diagnóstico y notificación"
gen tiempo_recuperacion=fecharecuperado-fis
label var tiempo_recuperacion "tiempo entre recuperación e inicio de síntomas"
gen tiempo_muerte=fechademuerte-fis 
label var tiempo_muerte "tiempo entre muerte e inicio de síntomas"
gen tiempo_ir_hospital=fechadenotificación-fis
label var tiempo_ir_hospital "tiempo entre fecha de not. e inicio de síntomas"

*Variable de semana 
gen semana=week(fechadiagnostico)
replace semana=semana-9
label var semana "semana de diagnostico después de primer caso confirmado"


*Dummies atención
gen casa=1 if atención=="CASA" 
replace casa=0 if casa==. 
gen fallecido=1 if atención=="FALLECIDO" 
replace fallecido=0 if fallecido==. 
gen hospital=1 if atención=="HOSPITAL" 
replace hospital=0 if hospital==. 
gen hospitaluci=1 if atención=="HOSPITAL UCI" 
replace hospitaluci=0 if hospitaluci==.
gen recuperado=1 if atención=="RECUPERADO" 
replace recuperado=0 if recuperado==. 
gen atencion_na=1 if atención=="N/A"
replace atencion_na=0 if atencion_na==. 


*Variable de activo
gen activo=1 if casa==1 | hospital==1 | hospitaluci==1  
replace activo=0 if fallecido==1 | recuperado==1 
label define activo 1 "ACTIVO" 0 "NO ACTIVO"
label values activo activo 
label var activo "Caso sigue activo"

*Dummies tipo 
gen enestudio=1 if tipo=="EN ESTUDIO" 
replace enestudio=0 if enestudio==. 
gen importado=1 if tipo=="IMPORTADO" 
replace importado=0 if importado==.
gen relacionado=1 if tipo=="RELACIONADO" 
replace relacionado=0 if relacionado==. 




/*
			Generating aggregated variables by departamento
*/

*Casos por departamento
egen casos_confirmados=count(iddecaso), by(departamento)

local vars "activo casa fallecido hospital hospitaluci recuperado enestudio importado relacionado"
foreach var in `vars'{
egen casos_`var'=sum(`var'), by(departamento)
}

*casos en hospital 
gen casos_total_hospital=casos_hospital+casos_hospitaluci 

*asintomaticos 
egen casos_asintomaticos=sum(tipo_sintomas), by(departamento)


/*
	Generating working datasets 	
*/

*In this section I generate a daily working dataset.

*Department datasets
local vars "pruebas poblacion camashospitalizacion camascuidadosintermedios camascuidadosintensivos numerodeprestadores tiempo_prueba tiempo_recuperacion tiempo_muerte tiempo_ir_hospital casos_confirmados casos_activo casos_casa casos_fallecido casos_hospital casos_hospitaluci casos_recuperado casos_enestudio casos_importado casos_relacionado casos_total_hospital casos_asintomaticos"
collapse `vars', by(codigo departamento) 

gen fecha="`i'-0`m'-2020"
order fecha, first
sort fecha
gen fecha1 = date(fecha,"DMY")
format fecha1 %tdNN/DD/CCYY
order fecha1, after(fecha)
drop fecha 
rename fecha1 fecha
save "$mod\departamentos\data_dpto_`i'_0`m'_2020.dta", replace
*export delimited using "$mod\departamentos\data_dpto_`i'_04_2020.csv", replace

*National datasets 
local vars "pruebas camashospitalizacion camascuidadosintermedios camascuidadosintensivos numerodeprestadores casos_confirmados casos_activo casos_casa casos_fallecido casos_hospital casos_hospitaluci casos_recuperado casos_enestudio casos_importado casos_relacionado casos_total_hospital casos_asintomaticos"
foreach var in `vars'{
egen nal_`var'=sum(`var')
drop `var'
rename nal_`var' `var'
}

collapse tiempo_prueba tiempo_recuperacion tiempo_muerte tiempo_ir_hospital pruebas camashospitalizacion camascuidadosintermedios camascuidadosintensivos numerodeprestadores casos_confirmados casos_activo casos_casa casos_fallecido casos_hospital casos_hospitaluci casos_recuperado casos_enestudio casos_importado casos_relacionado casos_total_hospital casos_asintomaticos

gen fecha="`i'-0`m'-2020"
order fecha, first 
gen fecha1 = date(fecha,"DMY")
format fecha1 %tdNN/DD/CCYY
order fecha1, after(fecha)
drop fecha 
rename fecha1 fecha
save "$mod\nacional\nal_`i'_0`m'_2020.dta", replace





/*
	Merging working datasets 
*/

*National dataset 
use "$mod\nacional\data_nal.dta", clear
append using "$mod\nacional\nal_`i'_0`m'_2020"
erase "$mod\nacional\nal_`i'_0`m'_2020.dta"
sort fecha
save "$mod\nacional\data_nal.dta", replace 
export delimited using "$mod\nacional\data_nal.csv", replace


*Department dataset
use "$mod\departamentos\data_dpto.dta", clear
append using "$mod\departamentos\data_dpto_`i'_0`m'_2020.dta"
erase "$mod\departamentos\data_dpto_`i'_0`m'_2020.dta"
sort fecha
save "$mod\departamentos\data_dpto.dta", replace
