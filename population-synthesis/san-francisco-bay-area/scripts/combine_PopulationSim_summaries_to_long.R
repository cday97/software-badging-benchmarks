#
# Combine PopulationSim output summary files to a single long form file
# for visualizing with validation.twb
#

library(tidyverse)
library(rlang)

all_summary_df <- tibble()

# See https://github.com/ActivitySim/populationsim/issues/67
# There is no county summary so create this one

# read config (controls.csv) and filter to county-level
county_configs_df <- read_csv(file.path("configs","controls.csv")) %>%
  filter(geography=="county")
# and controls
county_controls_df <- read_csv(file.path("data","control_totals_county.csv"))

# read geographies.csv to get taz->county
geo_df <- read_csv(file.path("data","geographies.csv")) %>% select(taz, county)

synthetics <- list()
# go through county controls and summarize. 
# (I know, I ought to use apply, but there are only 9 counties.)
for (row in 1:nrow(county_configs_df)) {
  seed_table     <- county_configs_df[[row, "seed_table"]]
  control_field  <- county_configs_df[[row, "control_field"]]
  expression     <- county_configs_df[[row, "expression"]]
  expression     <- str_replace(expression, paste0(seed_table,"."), "")
  print(paste("Summarizing results for", control_field))
  
  # read relevant table
  if (seed_table %in% names(synthetics)) {
    print(paste(seed_table,"synthetic already read -- skipping"))
  } else {
    print(paste(" Reading synthetic",seed_table))
    synthetics[[seed_table]] <- read.csv(file = file.path("output", 
      paste0("synthetic_",seed_table,".csv")))
    
    # attach to get county
    synthetics[[seed_table]] <- left_join(synthetics[[seed_table]],
                                          geo_df)
  }
  # summarize to county
  result_df <- filter(synthetics[[seed_table]], !! parse_expr(expression)) %>%
    group_by(county) %>% 
    summarise(n=n())

  # add county controls
  result_df <- left_join(result_df, 
                      select(county_controls_df, county, !! parse_expr(control_field)))
  result_df <- mutate(result_df, diff=n- !! parse_expr(control_field))
  
  names(result_df)[names(result_df)=="diff"       ] <- paste0(control_field,"_diff")
  names(result_df)[names(result_df)=="n"          ] <- paste0(control_field,"_result")
  names(result_df)[names(result_df)==control_field] <- paste0(control_field,"_control")
  
  # convert to columns: county, type, control, result, diff
  result_df <- pivot_longer(result_df,
                            cols=ends_with(c("_control","_result","_diff")),
                            names_to = c("control_field",".value"),
                            names_pattern = "(.*)_(control|result|diff)")
  names(result_df)[names(result_df)=="county"] <- "id"
  result_df <- mutate(result_df, geography="county")

  # keep it
  all_summary_df <- rbind(all_summary_df, result_df)
}

summary_files <- Sys.glob(file.path("output","final_summary_taz*.csv"))

for (summary_file in summary_files) {
  print(paste("Reading summary file", summary_file))
  summary_df <- read_csv(summary_file)
  # print(head(summary_df))

  # convert to columns: geography, id, type, control, result, diff
  summary_df <- pivot_longer(summary_df,
                             cols=ends_with(c("_control","_result","_diff")),
                             names_to = c("control_field",".value"),
                             names_pattern = "(.*)_(control|result|diff)")
  all_summary_df <- rbind(all_summary_df, summary_df)
}

output_file <- file.path("output","final_summary_long.csv")
write_csv(all_summary_df, output_file)
print(paste("Wrote",output_file))
