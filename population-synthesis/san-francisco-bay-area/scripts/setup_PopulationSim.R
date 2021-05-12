#
# setup PopulationSim files for this dataset
#
# Converts marginals file to control configuration (based on the straightforward marginals naming)
# for PopulationSim as well as the marginal controls files needed for each geography type.
#
# Run from the command line: Rscript --vanilla [path to this file]/setup_PopulationSim.R
#   input:  [path to this file]/../marginals.feather
# outputs: configs/controls.csv
#          data/control_totals_[county,taz].csv
#

library(tidyverse)
library(arrow)

# the marginals file path is in the parent directory from this script
args            <- commandArgs(trailingOnly = FALSE)
file.arg.name   <- "--file="
script.name     <- sub(file.arg.name, "", args[grep(file.arg.name, args)])
script.basename <- dirname(script.name)

# read the marginals
marginals_file <- file.path(script.basename, "..", "marginals.feather")
print(paste("Reading marginals file from",marginals_file))
marginals      <- read_feather(marginals_file)

# select geographies -- in this case, county and taz
# but let's pull it from data since it's so nicely formatted
geography_list <- unique(marginals["geography"])
geography_list <- sort(pull(geography_list)) # convert to sorted vector

# create controls_df from these three columns
# controls_df columns: target, geography, seed_table, importance, control_field, expression
controls_df <- unique(marginals[c("variable","geography","person_or_household")]) %>%
  rename(target     = variable,
         seed_table = person_or_household) %>%
  mutate(seed_table = recode(seed_table, "household"="households", "person"="persons")) %>%
  arrange(geography, seed_table,target)

# derive expression from the variable (or target) by parsing target column
controls_df <- mutate(controls_df,
                   control_field = target,
                   expr_name  = word(target,sep="_",1),
                   expr_value = word(target,sep="_",3,-1),
                   expr_range_min = suppressWarnings(as.numeric(str_match(expr_value, "(.*)(_to_|_or_more|_and_older)(.*)")[,2])),
                   expr_range_max = suppressWarnings(as.numeric(str_match(expr_value, "(.*)(_to_|_or_more|_and_older)(.*)")[,4])),
                   expr_value_num = suppressWarnings(as.numeric(expr_value)))

# put together the pieces into an expression
controls_df <- mutate(controls_df, 
                   expression = case_when(
                     # e.g., households.size == 1
                     !is.na(expr_value_num) ~ paste0(seed_table,".",expr_name," == ", expr_value_num),
                     # e.g., (persons.age >= 0) & (persons.age <= 4)
                     !is.na(expr_range_min) & !is.na(expr_range_max) ~ paste0("(", seed_table,".",expr_name," >= ",expr_range_min,") & (",
                                                                              seed_table,".",expr_name," <= ",expr_range_max,")"),
                     # e.g. (persons.age >= 65)
                     !is.na(expr_range_min) & is.na(expr_range_max) ~ paste0(seed_table,".",expr_name," >= ",expr_range_min),
                     # e.g. 
                     is.na(expr_value_num) & !is.na(expr_value) ~ paste0(seed_table,".",expr_name," == '", expr_value, "'"),
                     # number is special!
                     control_field == "number" ~ "(households.WGTP > 0) & (households.WGTP < np.inf)",
                     TRUE ~ "todo"))

# following example_calm, total number of households is most important control
controls_df <- mutate(controls_df,
                   importance = case_when(
                     target=="number" ~ 1000000000,
                     TRUE ~ 1000))

# select just the columns we want
controls_df <- select(controls_df, target, geography, seed_table, importance, control_field, expression)
controls_file <- file.path("configs","controls.csv")
write_csv(controls_df, controls_file)
print(paste("Wrote",controls_file))

# make control_totals_[geography].csv
for (geography_type in geography_list) {
  print(geography_type)
  # select the marginals for this geography and
  # then pivot to wide-form so the marginals are in their own columns
  geog_marginals <- filter(marginals, geography==geography_type) %>%
    select(-person_or_household, -geography) %>%
    pivot_wider(names_from=variable, values_from=marginal)
  
  # rename "geography_index" to the value of geography_type
  names(geog_marginals)[names(geog_marginals) == "geography_index"] <- geography_type

  # write them
  geog_marginals_file <- file.path("data",paste0("control_totals_",geography_type,".csv"))
  write_csv(geog_marginals, geog_marginals_file)
  print(paste("Wrote",geog_marginals_file))
}