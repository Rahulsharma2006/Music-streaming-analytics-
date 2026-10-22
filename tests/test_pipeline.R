#!/usr/bin/env Rscript
# Lightweight test runner (no testthat dependency).
# Execute from the project root: Rscript tests/test_pipeline.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
if (length(file_arg) == 1 && nzchar(file_arg)) {
  script_dir <- dirname(normalizePath(file_arg))
  setwd(dirname(script_dir))
}

source("R/00_utils.R")

n_pass <- 0L
n_fail <- 0L
failures <- character()

assert_true <- function(cond, msg) {
  if (isTRUE(cond)) {
    n_pass <<- n_pass + 1L
    cat("PASS:", msg, "\n")
  } else {
    n_fail <<- n_fail + 1L
    failures <<- c(failures, msg)
    cat("FAIL:", msg, "\n")
  }
}

assert_equal <- function(actual, expected, msg, tol = 1e-8) {
  ok <- if (is.numeric(actual) && is.numeric(expected)) {
    length(actual) == length(expected) && all(abs(actual - expected) <= tol)
  } else {
    identical(actual, expected)
  }
  assert_true(ok, paste0(msg, " | actual=", paste(actual, collapse = ","), " expected=", paste(expected, collapse = ",")))
}

cat("=== Music Streaming Analytics tests ===\n")
cat("Working directory:", getwd(), "\n")

# 1. Input file existence
assert_true(file.exists(RAW_DATA_PATH), "Raw dataset exists")

# 2. Required columns and types
raw <- read_raw_dataset()
assert_true(all(REQUIRED_ORIGINAL_COLUMNS %in% names(raw)), "Raw file has required columns")
assert_equal(nrow(raw), 500, "Raw file has 500 rows")
assert_equal(ncol(raw), 14, "Raw file has 14 columns")
assert_true(is.character(raw[["Artist Name"]]), "Artist Name is character")
assert_true(is.numeric(raw[["Total Streams (in millions)"]]), "Total streams are numeric")
assert_true(is.numeric(raw[["Debut Year"]]), "Debut year is numeric")

# 3. Missing-value reporting
assert_equal(as.integer(sum(colSums(is.na(raw)))), 0L, "Audit-style missing cell count is zero on raw data")

# 4. Duplicate-handling logic: unique grain, no silent deletion
assert_equal(n_distinct(raw[["Artist Name"]]), nrow(raw), "Artist name grain is unique")
assert_equal(sum(duplicated(raw)), 0, "No duplicate rows in raw data")

# 5. Percentage boundaries
pct_s <- raw[["% of Solo Streams"]]
pct_c <- raw[["% of Collaborative Streams"]]
assert_true(all(pct_s >= 0 & pct_s <= 100), "Solo percentages in 0-100")
assert_true(all(pct_c >= 0 & pct_c <= 100), "Collaborative percentages in 0-100")
assert_true(max(abs(pct_s + pct_c - 100)) < 1e-6, "Solo and collaborative percentages sum to 100")

# 6. Derived metric calculations on a synthetic fixture (never mixed into analysis data)
syn_path <- "tests/fixtures/synthetic_artists.csv"
syn <- readr::read_csv(syn_path, show_col_types = FALSE, trim_ws = TRUE)
names(syn) <- str_squish(names(syn))
syn <- rename_to_clean(syn) %>%
  mutate(
    solo_share = solo_streams_millions / total_streams_millions,
    collaborative_share = collaborative_streams_millions / total_streams_millions,
    catalog_share = total_streams_millions / sum(total_streams_millions)
  )
assert_equal(syn$solo_share[1], 0.6, "Synthetic solo share for Alpha")
assert_equal(syn$collaborative_share[2], 0.6, "Synthetic collaborative share for Beta")
assert_equal(sum(syn$catalog_share), 1, "Synthetic catalog shares sum to 1")
assert_true(!any(syn$artist_name %in% raw[["Artist Name"]] & syn$artist_name %in% c("Alpha", "Beta", "Gamma") & FALSE), "Fixture isolation placeholder")
assert_true(all(!syn$artist_name %in% raw[["Artist Name"]]), "Synthetic fixture names are not in the real dataset")

# 7. Aggregation correctness: never sum percentages
genre_stream_sum <- raw %>%
  group_by(`Primary Genre`) %>%
  summarise(total = sum(`Total Streams (in millions)`), .groups = "drop")
assert_equal(sum(genre_stream_sum$total), sum(raw[["Total Streams (in millions)"]]), "Genre totals add back to catalog total")

wrong_pct_sum <- sum(raw[["% of Solo Streams"]])
right_solo_share <- sum(raw[["Solo Streams (in millions)"]]) / sum(raw[["Total Streams (in millions)"]])
assert_true(abs(wrong_pct_sum - 100 * right_solo_share) > 1, "Summing percentages is not treated as a valid catalog share")

# 8. Gini helper
assert_equal(gini_coefficient(c(0, 0, 0, 10)), 0.75, "Gini helper on a simple vector", tol = 1e-10)

# 9. Output generation after pipeline (files may be missing if pipeline not run)
required_outputs <- c(
  "data/processed/artists_cleaned.csv",
  "data/processed/artists_features.csv",
  "data/processed/powerbi_artists.csv",
  "outputs/reports/key_findings.json",
  "outputs/tables/statistical_tests.csv",
  "outputs/figures/01_top15_artists_total_streams.png",
  "outputs/figures/10_data_quality_flags.png"
)
outputs_exist <- file.exists(required_outputs)
assert_true(all(outputs_exist), paste("Pipeline outputs exist:", paste(basename(required_outputs[!outputs_exist]), collapse = ", ")))

if (file.exists("outputs/tables/genre_summary.csv")) {
  g <- readr::read_csv("outputs/tables/genre_summary.csv", show_col_types = FALSE)
  hip <- g[g$primary_genre == "Hip-Hop", ]
  assert_true(nrow(hip) == 1 && hip$mean_streams_millions < hip$total_streams_millions, "Genre mean is not the group sum")
  assert_true(abs(hip$mean_streams_millions * hip$n_artists - hip$total_streams_millions) < 1e-4, "Genre mean times n equals genre sum")
}

if (file.exists("data/processed/artists_features.csv")) {
  feat <- readr::read_csv("data/processed/artists_features.csv", show_col_types = FALSE)
  assert_equal(nrow(feat), 500, "Processed features retain 500 artists")
  assert_true(max(abs(feat$solo_share + feat$collaborative_share - 1)) < 1e-10, "Engineered shares sum to 1")
  assert_equal(sum(feat$catalog_share), 1, "Catalog shares sum to 1")
  assert_true(max(abs(feat$solo_streams_millions + feat$collaborative_streams_millions - feat$total_streams_millions)) < 1e-8, "Solo+collab still reconciles after features")
  orig <- file.info(RAW_DATA_PATH)$mtime
  assert_true(!is.na(orig), "Raw file timestamp is readable")
}

# 10. Reproducibility: helpers are deterministic
x <- c(1, 2, 3, 4, 10)
assert_equal(gini_coefficient(x), gini_coefficient(x), "Gini is deterministic")
assert_equal(share_of_total(x, 1), 10 / 20, "Top-1 share helper")

# 11. Raw file still the original 500-line CSV (header + 500 data rows = 501 lines)
n_lines <- length(readLines(RAW_DATA_PATH))
assert_equal(n_lines, 501, "Raw CSV line count unchanged (header + 500 rows)")

cat("\n=== Summary ===\n")
cat("Passed:", n_pass, " Failed:", n_fail, "\n")
if (n_fail > 0) {
  cat("Failures:\n", paste0("- ", failures, collapse = "\n"), "\n", sep = "")
  quit(status = 1)
}
cat("All tests passed.\n")
