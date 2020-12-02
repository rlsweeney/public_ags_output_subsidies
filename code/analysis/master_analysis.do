/* RUN ALL OF THE ANALYSIS DO FILES */
********************************************************************************
clear
global repodir = substr("`c(pwd)'",1,length("`c(pwd)'") - (strpos(reverse("`c(pwd)'"),reverse("ags_capital_vs_output"))) + 1)

do "$repodir/code/setup.do"

tempsetup
********************************************************************************

*set graphics off

**********************************************
/* GET NEGATIVE PRICES BY WIND FARM */
do $repodir/code/analysis/summarize_negative_prices

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

********************************************************************************

/* EXPORT TABLES FOR DRAFT */
do $repodir/code/analysis/draft_stats

exit
