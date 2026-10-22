# Phase 2: clean the dataset while preserving the original CSV.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting data cleaning")

raw <- read_raw_dataset()

cleaning_log <- tibble::tibble(
  step = character(),
  detail = character(),
  n_rows = integer()
)

append_log <- function(step, detail, n_rows) {
  cleaning_log <<- bind_rows(
    cleaning_log,
    tibble(step = step, detail = detail, n_rows = as.integer(n_rows))
  )
}

append_log("read_raw", "Read the original CSV with trimmed header names. Raw file was not overwritten.", nrow(raw))

clean <- raw %>%
  mutate(across(where(is.character), ~ str_squish(.x))) %>%
  rename_to_clean() %>%
  mutate(
    artist_name = as.character(artist_name),
    sex = as.character(sex),
    country_of_origin = as.character(country_of_origin),
    primary_language = as.character(primary_language),
    primary_genre = as.character(primary_genre),
    artist_type = as.character(artist_type),
    debut_year = as.integer(round(debut_year)),
    across(
      c(
        total_streams_millions,
        lead_streams_millions,
        feature_streams_millions,
        solo_streams_millions,
        collaborative_streams_millions,
        pct_of_solo_streams,
        pct_of_collaborative_streams
      ),
      as.numeric
    )
  )

append_log(
  "normalize_names_and_types",
  "Mapped original headers to snake_case, squished character fields, stored debut_year as integer.",
  nrow(clean)
)

# Quality flags. No rows are dropped: grain is unique artists and none are duplicates.
clean <- clean %>%
  mutate(
    solo_collab_residual_millions = solo_streams_millions + collaborative_streams_millions - total_streams_millions,
    lead_feature_residual_millions = lead_streams_millions + feature_streams_millions - total_streams_millions,
    pct_sum_residual = pct_of_solo_streams + pct_of_collaborative_streams - 100,
    flag_lead_feature_mismatch = abs(lead_feature_residual_millions) > 0.5,
    flag_solo_collab_mismatch = abs(solo_collab_residual_millions) > 0.01,
    flag_pct_sum_mismatch = abs(pct_sum_residual) > 0.01,
    flag_pct_out_of_range = pct_of_solo_streams < 0 | pct_of_solo_streams > 100 |
      pct_of_collaborative_streams < 0 | pct_of_collaborative_streams > 100,
    flag_nonpositive_total = total_streams_millions <= 0,
    flag_year_out_of_range = debut_year < 1930 | debut_year > 2026,
    flag_duplicate_artist = duplicated(artist_name) | duplicated(artist_name, fromLast = TRUE)
  )

append_log(
  "quality_flags",
  paste0(
    "Flagged ", sum(clean$flag_lead_feature_mismatch),
    " artists whose lead+feature residual exceeds 0.5 million streams. ",
    "No rows deleted."
  ),
  nrow(clean)
)

stopifnot(nrow(clean) == 500)
stopifnot(!any(clean$flag_duplicate_artist))
stopifnot(!any(clean$flag_nonpositive_total))
stopifnot(!any(clean$flag_pct_out_of_range))
stopifnot(!any(clean$flag_solo_collab_mismatch))
stopifnot(!any(clean$flag_year_out_of_range))

write_csv_safe(clean, "data/processed/artists_cleaned.csv")
write_csv_safe(cleaning_log, "outputs/tables/cleaning_log.csv")

clean_notes <- c(
  "# Data Cleaning Log",
  "",
  paste("Generated:", project_stamp()),
  "",
  "## Policy",
  "",
  "- The original file `data/raw/Spotify Streaming Performance Dataset.csv` is never overwritten.",
  "- The observed grain is one row per artist. Duplicate rows were checked and none were found, so none were removed.",
  "- Missing values were checked and none were found.",
  "- Categorical values were whitespace-normalized only; country and genre labels were not recoded.",
  "- Lead + feature residuals are flagged rather than forced to equal total streams, because the mismatch is widespread and may reflect a source definition difference rather than a simple typo.",
  "- Solo + collaborative streams were treated as the additive decomposition of total streams.",
  "",
  "## Steps",
  "",
  paste0("- ", cleaning_log$step, ": ", cleaning_log$detail)
)
writeLines(clean_notes, "outputs/reports/02_data_cleaning.md")
log_msg("Data cleaning complete; rows =", nrow(clean))
