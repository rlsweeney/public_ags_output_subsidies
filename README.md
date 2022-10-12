# Replication Package for "Investment versus Output Subsidies: Implications of Alternative Incentives for Wind Energy" by Joseph E. Aldy, Todd D. Gerarden, and Richard L. Sweeney

**Abstract**

*This paper examines the choice between subsidizing investment and subsidizing output to promote socially desirable production. We exploit a natural experiment to estimate the impact of subsidy margin on the productivity of wind farms. Using instrumental variable and matching estimators, we find that investment subsidy claimants produce 10 to 12 percent less power than they would have under the output subsidy. Accounting for extensive margin effects, we show that output subsidies are more cost-effective than investment subsidies over a large range of output targets.*

**The manuscript and online appendix are available [here](manuscript/AGS_Output_Subsidies.pdf) and [here](manuscript/AGS_Output_Subsidies_Online_Appendices.pdf).**

Overview
--------
The code in this replication package takes as inputs a mixture of publicly available data and commercial data, and outputs the figures, tables, and LaTeX input files used in the paper.  Code is written primarily in Stata, however some figures are generated using the R programming language.  The replicator can run all of the paper's code by executing `code/build/master_build.do` and `code/analysis/master_analysis.do`. This will copy the final tables and figures used in the text to the `manuscript` directory, where separate PDFs of the main text and appendix can be compiled. The replicator should expect the full code to run for approximately 12-18 hours on a modern laptop computer.  If the replicator does not have access to the commercial data used in the paper (see below), all of analysis code can still be run using the cleaned `code/build` output `.dta` files provided in the `generated_data` directory. 

Data Availability and Provenance Statements
----------------------------
This paper uses several publicly accessible data sources, exact copies of which are included in the replication package. It also relies on several commercially accessible proprietary data sets, and one confidential dataset provided to the authors by U.S. Treasury. A list of sources and details on how the data can be obtained is provided in [data_sources.pdf](data_sources.pdf).

### Summary of Availability

- [ ] All data **are** publicly available.
- [X] Some data **cannot be made** publicly available.
- [ ] **No data can be made** publicly available.

### Statement about Rights

- [X] I certify that the author(s) of the manuscript have legitimate access to and permission to use the data used in this manuscript. 

### Options for Obtaining Data

All non-proprietary raw data files are provided on [Dataverse](https://doi.org/10.7910/DVN/DBVDU6). Due to Dataverse's size limits, all files are stored at the root level. Researcher's seeking to run the full code after obtaining the raw data should store the data in the file structure described in `filelist.txt` on Dataverse. A zip directory which preserves the folder structure is also available on [Dropbox](https://www.dropbox.com/s/ulqmr7w5ruwjne0/Data_PublicRepository.zip?dl=0). 

Once these data are obtained and placed in the proper folder structure, researchers can process all raw data by executing `code/build/master_build.do`. The tables and figures in the paper can then be produced by running `code/analysis/master_analysis.do`. 

For researchers without access to the raw data, we also include processed derivatives of these proprietary data sufficient to reproduce all the tables and figures in the paper. These files (equivalent to running `code/build/master_build.do` on the raw data) are provided in the [`generated_data`](generated_data) folder as (as Stata `.dta` files).  The tables and figures in the paper can then be produced by running `code/analysis/master_analysis.do`. 

Instructions to Replicators
---------------------------
### Software Requirements
- `Stata` version 15 or higher. 
- A LaTeX distribution.  See [CTAN](https://www.ctan.org) for some options if it is not already installed. 
- R 4.0.0

Note: the program `code/setup.do`, which is executed as part of the other `.do` files, will check for the presence of these packages and installs the newest version of them if they are not currently available.

### Running just the analysis code (not the data prep)
Just clone the repo and run `code/analysis/master_analysis.do`. `setup.do` calls an untracked file called `paths.do` which you can comment out. 

### Running the full code (including build)
- To run the build code, you need to have all the raw files saved in the directories described in [data_sources.pdf](data_sources.pdf) (see above).
- Store these locally and create a file called `paths.do` in the `code` folder in this repository. 
- In this file, add a line with a global linking to the local location of the data (ie `global dropbox "D:/Dropbox/projects/AGS_Data"`).
