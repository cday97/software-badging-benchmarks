```shell
setopt interactivecomments
# The above makes it so zsh is ok with my comments
# I am on macOS 112.0.1 Monterey

# add R to my path
export PATH=/Library/Frameworks/R.framework/Resources:$PATH

# this is the location of the SF Bay Area population synthesis example in software-badging-benchmarks
export zephyr_sf_dir=/Users/lmz/Documents/GitHub/software-badging-benchmarks/population-synthesis/san-francisco-bay-area

# Following the Installation instructions on https://activitysim.github.io/populationsim/getting_started.html
conda create -n popsim python=3.8
conda activate popsim
# Now in popsim environment...

conda install pytables
pip install activitysim

# Here, we'll diverge a bit from the instructions in order install (in editable mode) populationsim from a clone of my fork
# e.g. https://github.com/lmz/populationsim
# So my working directory is /Users/lzorn/Documents/GitHub/populationsim
pip install -e .

# Setup the example with the benchmark data
mkdir example_zephyr_sfbayarea
cd example_zephyr_sfbayarea
# Setup the standard subdirectories, pivoting from example_calm
mkdir configs
mkdir data
mkdir output
# Collect validation results across runs here
mkdir validation
cp $zephyr_sf_dir/scripts/validation.twb validation

# start with config from example_calm
cp ../example_calm/run_populationsim.py .
cp ../example_calm/configs/logging.yaml configs
# this one gets manual edits
cp ../example_calm/configs/settings.yaml configs
vim configs/settings.yaml
# Saved this into $zephyr_sf_dir/PopulationSim.md

# pull data from zephyr's software-badging-benchmarks repo
cp $zephyr_sf_dir/geographies.csv    data
cp $zephyr_sf_dir/household_seed.csv data
cp $zephyr_sf_dir/person_seed.csv    data

# create configs/controls.csv and and control totals (data/control_totals_[county,taz].csv)
# from the marginals.  
# Requires R (of course) and R libraries tidyverse and arrow.
Rscript --vanilla $zephyr_sf_dir/scripts/setup_PopulationSim.R
# create a suffix for saving results
export suffix=$(date +%y%m%d_%H%M)
cp configs/controls.csv validation/controls_$suffix.csv

# run it!
python run_populationsim.py
# output looks like this:
# Configured logging using basicConfig
# INFO:activitysim:Configured logging using basicConfig
# INFO - Read logging configuration from: configs/logging.yaml
# INFO - SETTING configs_dir: configs
# INFO - SETTING settings_file_name: settings.yaml
#
# ...
#
# INFO - trace_memory_info pipeline.run after write_synthetic_population rss: 0.85GB used: 4.28 GB percent: 65.3%
# INFO - trace_memory_info #MEM pipeline.run after run_models rss: 0.85GB used: 4.28 GB percent: 65.3%
# INFO - Time to execute run_model (13 models) : 1645.948 seconds (27.4 minutes)
# INFO - Time to execute all models : 1646.103 seconds (27.4 minutes)

# Summarize validation for tableau visualization
# Requires R (of course) and R library tidyverse.
Rscript --vanilla $zephyr_sf_dir/scripts/combine_PopulationSim_summaries_to_long.R
cp output/final_summary_long.csv validation/final_summary_long_$suffix.csv
```

Some things I found:
* PopulationSim doesn't seem to like string variables; the variables used in controls should be numeric
* PopulationSim doesn't handle a variable called "size"; I'm guessing it collides with pandas.DataFrame.size()
* Importance isn't relative. If you run PopulationSim with just total household controls and importance=1, it will validate poorly.  If you make importance=1000 it will validate perfectly.

The following is the settings.yaml file used above.
```yaml
####################################################################
# PopulationSim Properties
####################################################################


# Algorithm/Software Configuration
# ------------------------------------------------------------------
INTEGERIZE_WITH_BACKSTOPPED_CONTROLS: True
SUB_BALANCE_WITH_FLOAT_SEED_WEIGHTS: False
GROUP_BY_INCIDENCE_SIGNATURE: True
USE_SIMUL_INTEGERIZER: True
USE_CVXPY: False
max_expansion_factor: 50
MAX_BALANCE_ITERATIONS_SIMULTANEOUS: 1000

# Geographic Settings
# ------------------------------------------------------------------
geographies: [county, PUMA, taz]
seed_geography: PUMA


# Tracing
# ------------------------------------------------------------------
trace_geography:
  taz: 62

# Data Directory
# ------------------------------------------------------------------
data_dir: data

# Input Data Tables
# ------------------------------------------------------------------
# input_pre_processor input_table_list
input_table_list:
  - tablename: households
    filename : household_seed.csv
    index_col: unique_hh_id
    column_map:
      hhnum: unique_hh_id
  - tablename: persons
    filename : person_seed.csv
    column_map:
      hhnum: unique_hh_id
      SPORDER: SPORDER
    # drop mixed type fields that appear to have been incorrectly generated
    drop_columns:
  - tablename: geo_cross_walk
    filename : geographies.csv
  - tablename: taz_control_data
    filename : control_totals_taz.csv
  - tablename: county_control_data
    filename : control_totals_county.csv

# Reserved Column Names
# ------------------------------------------------------------------
household_weight_col: WGTP
household_id_col: unique_hh_id
total_hh_control: number


# Control Specification File Name
# ------------------------------------------------------------------
control_file_name: controls.csv

# Output Tables
# ------------------------------------------------------------------
# output_tables can specify either a list of output tables to include or to skip
# if neither is specified, then no tables will be written

output_tables:
  action: include
  tables:
    - summary_taz
    - summary_taz_PUMA
    - summary_county_1
    - summary_county_2
    - summary_county_3
    - summary_county_4
    - summary_county_5
    - summary_county_6
    - summary_county_7
    - summary_county_8
    - summary_county_9
    - expanded_household_ids
    - trace_taz_weights

# Synthetic Population Output Specification
# ------------------------------------------------------------------
#

output_synthetic_population:
  household_id: household_id
  households:
    filename: synthetic_households.csv
    columns:
      # keep all the columns in household_seed.csv
      - RT
      - SERIALNO
      - DIVISION
      - PUMA
      - REGION
      - ST
      - ADJINC
      - WGTP
      - NP
      - TYPE
      - BLD
      - HHT
      - HINCP
      - HUPAC
      - NPF
      - TEN
      - VEH
      - county_index
      - unique_hh_id
      - weight
      - hhsize
      - incomeQ
      - workers

  persons:
    filename: synthetic_persons.csv
    # keep all the columns in person_seed.csv
    columns:
      - RT
      - SERIALNO
      - SPORDER
      - PUMA
      - ST
      - PWGTP
      - AGEP
      - COW
      - MAR
      - MIL
      - RELP
      - SCHG
      - SCHL
      - SEX
      - WKHP
      - WKW
      - ESR
      - HISP
      - PINCP
      - POWPUMA
      - unique_hh_id
      - county_index
      - age
      - occupation
      - gqtype

# Model steps for base mode
# ------------------------------------------------------------------
models:
    - input_pre_processor
    - setup_data_structures
    - initial_seed_balancing
    - meta_control_factoring
    - final_seed_balancing
    - integerize_final_seed_weights
    - sub_balancing.geography=taz
    - sub_balancing.geography=county
    - expand_households
    - write_data_dictionary
    - summarize
    - write_tables
    - write_synthetic_population

resume_after:
```
