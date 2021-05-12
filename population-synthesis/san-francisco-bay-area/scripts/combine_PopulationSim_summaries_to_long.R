#
# Combine PopulationSim output summary files to a single long form file
# for visualizing with validation.twb
#

library(tidyverse)

summary_files <- Sys.glob(file.path("output","final_summary_taz*.csv"))

all_summary_df <- tibble()
for (summary_file in summary_files) {
  print(paste("Reading summary file", summary_file))
  summary_df <- read_csv(summary_file)
  # print(head(summary_df))
  
  # convert to columns: geography, id, type, control, result, diff
  summary_df <- pivot_longer(summary_df, 
                             cols=ends_with(c("_control","_result","_diff")),
                             names_to = c("variable",".value"),
                             names_pattern = "(.*)_(control|result|diff)")
  all_summary_df <- rbind(all_summary_df, summary_df)
}

output_file <- file.path("output","final_summary_long.csv")
write_csv(all_summary_df, output_file)
print(paste("Wrote",output_file))