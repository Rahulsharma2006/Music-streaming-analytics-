# Phase 7: typed Power BI-ready tables. Aggregation uses sums of streams, never sums of percentages.

source("R/00_utils.R")
ensure_dirs()
log_msg("Exporting Power BI datasets")

artists <- readr::read_csv("data/processed/artists_features.csv", show_col_types = FALSE)

pbi_artists <- artists %>%
  transmute(
    artist_name,
    sex,
    country_of_origin,
    primary_language,
    primary_genre,
    artist_type,
    debut_year = as.integer(debut_year),
    debut_decade = as.integer(debut_decade),
    debut_era,
    total_streams_millions,
    lead_streams_millions,
    feature_streams_millions,
    solo_streams_millions,
    collaborative_streams_millions,
    solo_share,
    collaborative_share,
    lead_share,
    feature_share,
    catalog_share,
    artist_rank_total_streams = as.integer(artist_rank_total_streams),
    flag_lead_feature_mismatch,
    flag_iqr_high_total,
    lead_feature_residual_millions
  )

pbi_genre <- artists %>%
  group_by(primary_genre) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    solo_streams_millions = sum(solo_streams_millions),
    collaborative_streams_millions = sum(collaborative_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(
    collaborative_share = collaborative_streams_millions / total_streams_millions,
    catalog_share = total_streams_millions / sum(total_streams_millions)
  )

pbi_country <- artists %>%
  group_by(country_of_origin) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    solo_streams_millions = sum(solo_streams_millions),
    collaborative_streams_millions = sum(collaborative_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions))

pbi_language <- artists %>%
  group_by(primary_language) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(catalog_share = total_streams_millions / sum(total_streams_millions))

pbi_type <- artists %>%
  group_by(artist_type) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    solo_streams_millions = sum(solo_streams_millions),
    collaborative_streams_millions = sum(collaborative_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(collaborative_share = collaborative_streams_millions / total_streams_millions)

pbi_era <- artists %>%
  group_by(debut_era, debut_decade) %>%
  summarise(
    n_artists = n(),
    median_streams_millions = median(total_streams_millions),
    total_streams_millions = sum(total_streams_millions),
    collaborative_streams_millions = sum(collaborative_streams_millions),
    .groups = "drop"
  ) %>%
  mutate(collaborative_share = collaborative_streams_millions / total_streams_millions)

pbi_quality <- tibble(
  issue = c(
    "Missing cells",
    "Duplicate artist names",
    "Lead + feature residual > 0.5 million",
    "IQR high total-stream outliers",
    "Percentage values outside 0-100",
    "Solo + collaborative residual > 0.01 million"
  ),
  n = c(
    0L,
    as.integer(sum(artists$flag_duplicate_artist)),
    as.integer(sum(artists$flag_lead_feature_mismatch)),
    as.integer(sum(artists$flag_iqr_high_total)),
    as.integer(sum(artists$flag_pct_out_of_range)),
    as.integer(sum(artists$flag_solo_collab_mismatch))
  )
)

pbi_kpis <- tibble(
  kpi = c(
    "total_streams_millions",
    "distinct_artists",
    "distinct_genres",
    "distinct_countries",
    "distinct_languages",
    "leading_artist",
    "leading_genre",
    "median_streams_millions",
    "collaborative_share_catalog"
  ),
  value = c(
    as.character(sum(artists$total_streams_millions)),
    as.character(n_distinct(artists$artist_name)),
    as.character(n_distinct(artists$primary_genre)),
    as.character(n_distinct(artists$country_of_origin)),
    as.character(n_distinct(artists$primary_language)),
    artists$artist_name[which.max(artists$total_streams_millions)],
    pbi_genre$primary_genre[which.max(pbi_genre$total_streams_millions)],
    as.character(median(artists$total_streams_millions)),
    as.character(sum(artists$collaborative_streams_millions) / sum(artists$total_streams_millions))
  )
)

write_csv_safe(pbi_artists, "data/processed/powerbi_artists.csv")
write_csv_safe(pbi_genre, "data/processed/powerbi_genre.csv")
write_csv_safe(pbi_country, "data/processed/powerbi_country.csv")
write_csv_safe(pbi_language, "data/processed/powerbi_language.csv")
write_csv_safe(pbi_type, "data/processed/powerbi_artist_type.csv")
write_csv_safe(pbi_era, "data/processed/powerbi_debut_era.csv")
write_csv_safe(pbi_quality, "data/processed/powerbi_quality.csv")
write_csv_safe(pbi_kpis, "data/processed/powerbi_kpis.csv")

# Convenience copies inside powerbi/ for import from one folder.
file.copy("data/processed/powerbi_artists.csv", "powerbi/powerbi_artists.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_genre.csv", "powerbi/powerbi_genre.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_country.csv", "powerbi/powerbi_country.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_language.csv", "powerbi/powerbi_language.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_artist_type.csv", "powerbi/powerbi_artist_type.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_debut_era.csv", "powerbi/powerbi_debut_era.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_quality.csv", "powerbi/powerbi_quality.csv", overwrite = TRUE)
file.copy("data/processed/powerbi_kpis.csv", "powerbi/powerbi_kpis.csv", overwrite = TRUE)

log_msg("Power BI export complete")
