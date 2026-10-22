#!/usr/bin/env Rscript
# End-to-end runner. Execute from the project root:
#   Rscript R/run_pipeline.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
if (length(file_arg) == 1 && nzchar(file_arg)) {
  script_dir <- dirname(normalizePath(file_arg))
  setwd(dirname(script_dir))
}

source("R/00_utils.R")
ensure_dirs()

log_file <- file.path("logs", "pipeline.log")
log_con <- file(log_file, open = "wt")
sink(log_con, split = TRUE)
sink(log_con, type = "message")
on.exit({
  sink(type = "message")
  sink()
  close(log_con)
}, add = TRUE)

started <- Sys.time()
log_msg("Pipeline start in", getwd())

scripts <- c(
  "R/01_data_audit.R",
  "R/02_data_cleaning.R",
  "R/03_feature_engineering.R",
  "R/04_exploratory_analysis.R",
  "R/05_statistical_analysis.R",
  "R/06_visualizations.R",
  "R/07_export_powerbi_data.R"
)

for (s in scripts) {
  log_msg("Running", s)
  source(s, local = new.env())
}

elapsed <- round(difftime(Sys.time(), started, units = "secs"), 2)
log_msg("Pipeline finished in", elapsed, "seconds")
cat("OK\n")
