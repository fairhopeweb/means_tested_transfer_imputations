/*
*****************************************************************************************
** Main file to replicate the means-tested transfer imputations that CBO uses 
** in its analyses of the distribution of household income.
*****************************************************************************************
*/
clear all
set more off
capture log close


/*
*****************************************************************************************
** SET PATH VARIABLES
*****************************************************************************************
*/
// Uncomment the line below and enter the directory path where this .do file is saved.
// global source_code_path "enter\your\path\to\means_tested_transfer_imputations\source_code"
cd $source_code_path
global input_path "..\inputs"
global output_data_path "..\outputs\data"
global output_diagnostics_path "..\outputs\diagnostics"


/*
*****************************************************************************************
** SET START AND END YEARS
*****************************************************************************************
*/
global cps_start_year = 1980
global cps_end_year = 2022


/*
*****************************************************************************************
** PREPARE DATA TO RUN THE ALGORITHM BY SUBGROUP
*****************************************************************************************
*/
log using "$output_diagnostics_path\impute_means_tested_transfers_log.txt", replace text

insheet using "$input_path\CBO_targets_means_tested_transfers.csv", clear
save "$input_path\CBO_targets_means_tested_transfers.dta", replace

// The imputation method is conducted separately for eight subgroups across the
// three means-tested transfer programs.
#delimit ;
local subgroups "mcaid_adult
                 mcaid_child
                 mcaid_senior
                 mcaid_disabled
                 snap_allhhd
                 ssi_adult
                 ssi_child
                 ssi_senior";
#delimit cr

foreach cps_year of numlist $cps_start_year / $cps_end_year {

  insheet using "$input_path\CBO_probabilities_means_tested_transfers_`cps_year'.csv", clear

  qui merge m:1 cps_year using "$input_path\CBO_targets_means_tested_transfers.dta"
  drop if _merge != 3
  drop _merge

  // Loop through the three means-tested programs to create the variables
  // for the imputed recipiency status and imputed benefit values. The algorithm
  // will fill in these variables as it moves through the subgroups.
  foreach program in mcaid snap ssi housing_assist {

    gen `program'_impute = 0
    label var `program'_impute "Post-imputation recipient of `program'"

    gen `program'_impute_val = 0
    label var `program'_impute_val "Post-imputation value of `program' benefits"

  }


  /*
  ***************************************************************************************
  ** LOOP THROUGH SUBGROUPS TO ASSIGN TRANSFER RECEIPT
  ***************************************************************************************
  */
  foreach group in `subgroups' {
    do assign_transfer_receipt.do "`group'"
  }

  // For housing subsidies, CBO does not impute additional recipients beyond the units
  // that report receipt in the CPS. However, the agency does estimate benefit values
  // for reporting units. Those values are included in the accompanying datasets.
  replace housing_assist_impute = housing_assist_report
  replace housing_assist_impute_val = housing_assist_potential_val

  drop *potential* *target* *child *adult *senior *allhhd *disabled *prob *rand *report
  save "$output_data_path\CBO_imputed_means_tested_transfers_`cps_year'.dta", replace

} // End of foreach year... loop


/*
*****************************************************************************************
** USE OUTPUT DATASETS TO CREATE CSV WITH SUMMARY STATISTICS
*****************************************************************************************
*/
do produce_summary_statistics.do

log close
clear all
