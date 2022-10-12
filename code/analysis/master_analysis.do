/* RUN ALL OF THE ANALYSIS DO FILES */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************

*set graphics off

**********************************************
/* DEFINE SAMPLE */
do $repodir/code/analysis/define_sample

**********************************************
/* WIND FARM MAPS */
do $repodir/code/analysis/make_maps 

/* SUMMARY STATISTICS */
do $repodir/code/analysis/summary_stats

do $repodir/code/analysis/wind_variable_selection

do $repodir/code/analysis/proposal_analysis

/* FUZZY RDD (IV) */
do $repodir/code/analysis/rdd_regressions

/* MATCHING */
do $repodir/code/analysis/matching

/* POLICY EVALUATION */
do $repodir/code/analysis/predict_costs

do $repodir/code/analysis/prep_policyeval

do $repodir/code/analysis/1603_policy_eval

do $repodir/code/analysis/cost_effectiveness

do $repodir/code/analysis/pm_model

/* NEGATIVE PRICES*/
do $repodir/code/analysis/summarize_negative_prices // node summary 

do $repodir/code/analysis/match_nodes_to_plants

* note this takes a LONG time (need to rerun on desktop)
do $repodir/code/analysis/get_negative_price_production

do $repodir/code/analysis/rdd_regressions_negative_lmp

********************************************************************************

/* EXPORT TABLES FOR DRAFT */
do $repodir/code/analysis/draft_stats

* Copy all output to the manuscript directory 
do $repodir/code/analysis/move_output_to_manuscript

exit
