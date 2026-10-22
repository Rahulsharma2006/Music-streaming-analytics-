# Phase 3: derive metrics from observed columns only.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting feature engineering")

clean <- readr::read_csv("data/processed/artists_cleaned.csv", show_col_types = FALSE)

iqr_total_upper <- iqr_bounds(clean$total_streams_millions)$upper

features <- clean %>%
  mutate(
    # Shares as 0-1 proportions computed from stream counts, not by summing percentages.
    solo_share = solo_streams_millions / total_streams_millions,
    collaborative_share = collaborative_streams_millions / total_streams_millions,
    lead_share = lead_streams_millions / total_streams_millions,
    feature_share = feature_streams_millions / total_streams_millions,
    catalog_share = total_streams_millions / sum(total_streams_millions),
    log10_total_streams = log10(total_streams_millions),
    debut_decade = 10 * floor(debut_year / 10),
    debut_era = debut_era(debut_year),
    is_group = artist_type == "Group",
    is_solo_artist = artist_type == "Solo"
  ) %>%
  group_by(primary_genre) %>%
  mutate(
    genre_artist_count = n(),
    genre_total_streams_millions = sum(total_streams_millions),
    genre_median_streams_millions = median(total_streams_millions)
  ) %>%
  ungroup() %>%
  mutate(
    artist_rank_total_streams = min_rank(desc(total_streams_millions)),
    flag_iqr_high_total = total_streams_millions > iqr_total_upper
  ) %>%
  arrange(artist_rank_total_streams)

metric_dictionary <- tibble::tribble(
  ~metric, ~formula, ~unit, ~assumption,
  "solo_share", "solo_streams_millions / total_streams_millions", "proportion 0-1", "Solo and total streams are in the same million-stream units.",
  "collaborative_share", "collaborative_streams_millions / total_streams_millions", "proportion 0-1", "Collaborative and total streams are in the same million-stream units.",
  "lead_share", "lead_streams_millions / total_streams_millions", "proportion 0-1", "Lead streams are not assumed to be a complete partition of total streams.",
  "feature_share", "feature_streams_millions / total_streams_millions", "proportion 0-1", "Feature streams are not assumed to be a complete partition of total streams.",
  "catalog_share", "total_streams_millions / sum(total_streams_millions)", "proportion 0-1", "The 500-artist file is the catalog; this is not a share of all Spotify streams.",
  "log10_total_streams", "log10(total_streams_millions)", "log10 millions", "Totals are positive, which was verified.",
  "debut_decade", "10 * floor(debut_year / 10)", "decade start year", "Debut year is an integer calendar year.",
  "debut_era", "custom bins of debut_year", "categorical era", "Bins describe debut timing, not when streams were earned.",
  "artist_rank_total_streams", "min_rank(desc(total_streams_millions))", "rank 1 = highest", "Ties receive the minimum rank.",
  "flag_iqr_high_total", "total > Q3 + 1.5 IQR", "boolean", "IQR rule is a diagnostic, not a deletion rule."
)

write_csv_safe(features, "data/processed/artists_features.csv")
write_csv_safe(metric_dictionary, "data/reference/derived_metrics.csv")
write_csv_safe(metric_dictionary, "outputs/tables/derived_metric_dictionary.csv")
log_msg("Feature engineering complete")
