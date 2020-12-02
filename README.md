# Aldy, Gerarden and Sweeney (2020): Data and code for replication

This repo contains the data and code for replication for "Investment versus Output Subsidies: Implications of Alternative Incentives for Wind Energy"

**Abstract**

*This paper examines the choice between subsidizing investment and subsidizing output to promote socially desirable production. We exploit a natural experiment to estimate the impact of subsidy margin on the productivity of wind farms. Using instrumental variable and matching estimators, we find that investment subsidy claimants produce 10 to 12 percent less power than they would have under the output subsidy. Accounting for extensive margin effects, we show that output subsidies are more cost-effective than investment subsidies over a large range of output targets.*

A **draft** of the paper is available [here](draft/AGS_Output_Subsidies.pdf).

## Data 

A list of sources and details on how the data can be obtained is provided [here](data_sources.pdf). Most the data is in the public domain, **however some of the data is proprietary**. For researchers without access to these sources, we also include processed derivatives of these proprietary data sufficient to reproduce all of the tables and figures in the paper. The [`generated_data`](generated_data) folder contains all of the data (as Stata .dta files) neccessary to run all of the code in the [`analysis`](code/analysis) folder. ["Build"](code/build) code, which produces the intermediate data is provided for those able to obtain the proprietary data sets. 

## Running the code 
### Running just the analysis code (not the data prep)
Just clone the repo and run `code/analysis/master_analysis.do`. `setup.do` calls an untracked file called `paths.do` which you can comment out. 

### Notes on running the full code (including build)
- to run the build code, you need to have all of the raw files saved in the directories described in [data_sources.pdf](data_sources.pdf)
- store these locally and create a file called `code/paths.do`. 
- in it, place a line with a global linking to the local location of the data (ie `global dropbox "D:/Dropbox/projects/1603"`)
- THIS ONLY NEEDS TO BE DONE ONCE! (per computer)
