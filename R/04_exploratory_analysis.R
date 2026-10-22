# Phase 4: exploratory summaries used by reports and Power BI.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting exploratory analysis")

artists <- readr::read_csv("data/processed/artists_features.csv", show_col_types = FALSE)

top_artists <- artists %>%
  transmute(
    artist_rank_total_streams,
    artist_name,
    primary_genre,
    country_of_origin,
    artist_type,
    debut_year,
    total_streams_millions,
    solo_streams_millions,
    collaborative_streams_millions,
    solo_share,
    collaborative_share,
    catalog_share
  ) %>%
  arrange(artist_rank_total_streams)

genre_summary <- artists %>%
  group_by(primary_genre) %>%
  summarise(
    n_artists = n(),
    mean_streams_millions = mean(total_streams_millions),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    mean_collaborative_share = mean(collaborative_share),
    median_collaborative_share = median(collaborative_share),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions)) %>%
  arrange(desc(total_streams_millions))

country_summary <- artists %>%
  group_by(country_of_origin) %>%
  summarise(
    n_artists = n(),
    mean_streams_millions = mean(total_streams_millions),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions)) %>%
  arrange(desc(total_streams_millions))

language_summary <- artists %>%
  group_by(primary_language) %>%
  summarise(
    n_artists = n(),
    mean_streams_millions = mean(total_streams_millions),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions)) %>%
  arrange(desc(total_streams_millions))

artist_type_summary <- artists %>%
  group_by(artist_type) %>%
  summarise(
    n_artists = n(),
    mean_streams_millions = mean(total_streams_millions),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    mean_solo_share = mean(solo_share),
    mean_collaborative_share = mean(collaborative_share),
    .groups = "drop"
  )

sex_summary <- artists %>%
  group_by(sex, artist_type) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    .groups = "drop"
  )

debut_era_summary <- artists %>%
  group_by(debut_era) %>%
  summarise(
    n_artists = n(),
    mean_streams_millions = mean(total_streams_millions),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    mean_collaborative_share = mean(collaborative_share),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions)) %>%
  arrange(debut_era)

solo_collab_totals <- tibble(
  component = c("Solo streams", "Collaborative streams"),
  streams_millions = c(sum(artists$solo_streams_millions), sum(artists$collaborative_streams_millions))
) %>%
  mutate(share = streams_millions / sum(streams_millions))

quality_summary <- tibble(
  metric = c(
    "rows",
    "unique_artists",
    "missing_cells",
    "duplicate_artists",
    "lead_feature_mismatch_flags",
    "iqr_high_total_outliers",
    "solo_collab_mismatch_flags",
    "pct_out_of_range_flags"
  ),
  value = c(
    nrow(artists),
    n_distinct(artists$artist_name),
    0,
    sum(artists$flag_duplicate_artist),
    sum(artists$flag_lead_feature_mismatch),
    sum(artists$flag_iqr_high_total),
    sum(artists$flag_solo_collab_mismatch),
    sum(artists$flag_pct_out_of_range)
  )
)

write_csv_safe(top_artists, "outputs/tables/top_artists.csv")
write_csv_safe(genre_summary, "outputs/tables/genre_summary.csv")
write_csv_safe(country_summary, "outputs/tables/country_summary.csv")
write_csv_safe(language_summary, "outputs/tables/language_summary.csv")
write_csv_safe(artist_type_summary, "outputs/tables/artist_type_summary.csv")
write_csv_safe(sex_summary, "outputs/tables/sex_by_artist_type_summary.csv")
write_csv_safe(debut_era_summary, "outputs/tables/debut_era_summary.csv")
write_csv_safe(solo_collab_totals, "outputs/tables/solo_collaborative_totals.csv")
write_csv_safe(quality_summary, "outputs/tables/quality_summary.csv")

log_msg("Exploratory analysis complete")
