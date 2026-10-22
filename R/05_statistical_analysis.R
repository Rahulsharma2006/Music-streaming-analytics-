# Phase 5: distributional summaries and assumption-aware tests.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting statistical analysis")

artists <- readr::read_csv("data/processed/artists_features.csv", show_col_types = FALSE)

tot <- artists$total_streams_millions
iqr_tot <- iqr_bounds(tot)

numeric_distribution <- map_dfr(
  c(
    "total_streams_millions",
    "lead_streams_millions",
    "feature_streams_millions",
    "solo_streams_millions",
    "collaborative_streams_millions",
    "solo_share",
    "collaborative_share",
    "debut_year"
  ),
  function(col) {
    x <- artists[[col]]
    tibble(
      metric = col,
      n = length(x),
      mean = mean(x),
      median = median(x),
      sd = sd(x),
      min = min(x),
      q1 = as.numeric(quantile(x, 0.25)),
      q3 = as.numeric(quantile(x, 0.75)),
      max = max(x),
      skewness_g1 = skewness_g1(x),
      excess_kurtosis_g2 = kurtosis_g2(x)
    )
  }
)

shapiro_total <- shapiro.test(tot)
shapiro_log <- shapiro.test(artists$log10_total_streams)

solo_vals <- artists$total_streams_millions[artists$artist_type == "Solo"]
group_vals <- artists$total_streams_millions[artists$artist_type == "Group"]
wilcox_type <- wilcox.test(solo_vals, group_vals, alternative = "two.sided", exact = FALSE, conf.int = TRUE)
delta_type <- cliffs_delta(solo_vals, group_vals)

# Sex comparison restricted to solo artists because Mixed is only used for groups.
solo_artists <- artists %>% filter(artist_type == "Solo", sex %in% c("Female", "Male"))
female_vals <- solo_artists$total_streams_millions[solo_artists$sex == "Female"]
male_vals <- solo_artists$total_streams_millions[solo_artists$sex == "Male"]
wilcox_sex <- wilcox.test(female_vals, male_vals, alternative = "two.sided", exact = FALSE, conf.int = TRUE)
delta_sex <- cliffs_delta(female_vals, male_vals)

spearman_collab <- cor.test(
  artists$collaborative_share,
  artists$total_streams_millions,
  method = "spearman",
  exact = FALSE
)
spearman_debut <- cor.test(
  artists$debut_year,
  artists$total_streams_millions,
  method = "spearman",
  exact = FALSE
)
spearman_solo_share <- cor.test(
  artists$solo_share,
  artists$total_streams_millions,
  method = "spearman",
  exact = FALSE
)

pearson_log_collab <- cor.test(
  artists$collaborative_share,
  artists$log10_total_streams,
  method = "pearson"
)

genre_n10 <- artists %>%
  group_by(primary_genre) %>%
  filter(n() >= 10) %>%
  ungroup()
kruskal_genre <- kruskal.test(total_streams_millions ~ primary_genre, data = genre_n10)

stream_cor <- artists %>%
  select(
    total_streams_millions,
    lead_streams_millions,
    feature_streams_millions,
    solo_streams_millions,
    collaborative_streams_millions,
    collaborative_share,
    debut_year
  ) %>%
  cor(method = "spearman")

concentration <- tibble(
  metric = c("top_10_share", "top_50_share", "top_100_share", "gini_total_streams", "n_iqr_high_outliers"),
  value = c(
    share_of_total(tot, 10),
    share_of_total(tot, 50),
    share_of_total(tot, 100),
    gini_coefficient(tot),
    sum(artists$flag_iqr_high_total)
  )
)

tests <- tibble(
  test = c(
    "shapiro_total_streams",
    "shapiro_log10_total_streams",
    "wilcoxon_solo_vs_group_total_streams",
    "wilcoxon_female_vs_male_solo_artists_total_streams",
    "spearman_collaborative_share_vs_total",
    "spearman_debut_year_vs_total",
    "spearman_solo_share_vs_total",
    "pearson_collaborative_share_vs_log10_total",
    "kruskal_genre_n_ge_10_total_streams"
  ),
  n = c(
    length(tot),
    length(tot),
    length(solo_vals) + length(group_vals),
    length(female_vals) + length(male_vals),
    nrow(artists),
    nrow(artists),
    nrow(artists),
    nrow(artists),
    nrow(genre_n10)
  ),
  statistic = c(
    unname(shapiro_total$statistic),
    unname(shapiro_log$statistic),
    unname(wilcox_type$statistic),
    unname(wilcox_sex$statistic),
    unname(spearman_collab$estimate),
    unname(spearman_debut$estimate),
    unname(spearman_solo_share$estimate),
    unname(pearson_log_collab$estimate),
    unname(kruskal_genre$statistic)
  ),
  p_value = c(
    shapiro_total$p.value,
    shapiro_log$p.value,
    wilcox_type$p.value,
    wilcox_sex$p.value,
    spearman_collab$p.value,
    spearman_debut$p.value,
    spearman_solo_share$p.value,
    pearson_log_collab$p.value,
    kruskal_genre$p.value
  ),
  effect_or_note = c(
    "Rejects normality of raw totals if p is small; expected for right-skewed streaming data.",
    "Log10 transform still may not be Gaussian; used only as a diagnostic.",
    paste0("Cliff's delta (Solo minus Group) = ", round(delta_type, 4), ". Positive means Solo tends to rank higher."),
    paste0("Cliff's delta (Female minus Male, solo artists) = ", round(delta_sex, 4), "."),
    "Spearman rho; association, not a causal effect of collaboration.",
    "Spearman rho; debut year is not a performance time series.",
    "Spearman rho; complement of collaborative share.",
    "Pearson r on log10 totals versus collaborative share.",
    paste0("Restricted to genres with at least 10 artists (", n_distinct(genre_n10$primary_genre), " genres).")
  )
)

type_conf <- if (!is.null(wilcox_type$conf.int)) {
  paste0(
    "Hodges-Lehmann median difference (Solo - Group) = ",
    round(wilcox_type$estimate, 2),
    " million; 95% CI [",
    round(wilcox_type$conf.int[1], 2), ", ",
    round(wilcox_type$conf.int[2], 2), "]"
  )
} else {
  "Confidence interval unavailable."
}

key_values <- list(
  generated_at = project_stamp(),
  n_artists = nrow(artists),
  sum_total_streams_millions = sum(tot),
  mean_total = mean(tot),
  median_total = median(tot),
  sd_total = sd(tot),
  min_total = min(tot),
  max_total = max(tot),
  skewness_total = skewness_g1(tot),
  leading_artist = artists$artist_name[which.max(tot)],
  leading_artist_streams = max(tot),
  leading_genre_by_sum = artists %>%
    group_by(primary_genre) %>%
    summarise(s = sum(total_streams_millions), .groups = "drop") %>%
    slice_max(s, n = 1) %>%
    pull(primary_genre),
  leading_country_by_sum = artists %>%
    group_by(country_of_origin) %>%
    summarise(s = sum(total_streams_millions), .groups = "drop") %>%
    slice_max(s, n = 1) %>%
    pull(country_of_origin),
  n_genres = n_distinct(artists$primary_genre),
  n_countries = n_distinct(artists$country_of_origin),
  n_languages = n_distinct(artists$primary_language),
  n_solo = sum(artists$artist_type == "Solo"),
  n_group = sum(artists$artist_type == "Group"),
  solo_stream_share = sum(artists$solo_streams_millions) / sum(tot),
  collab_stream_share = sum(artists$collaborative_streams_millions) / sum(tot),
  mean_collab_share = mean(artists$collaborative_share),
  median_collab_share = median(artists$collaborative_share),
  top10_share = share_of_total(tot, 10),
  top50_share = share_of_total(tot, 50),
  top100_share = share_of_total(tot, 100),
  gini = gini_coefficient(tot),
  n_iqr_outliers = sum(artists$flag_iqr_high_total),
  iqr_upper = iqr_tot$upper,
  n_lead_feature_mismatch = sum(artists$flag_lead_feature_mismatch),
  wilcox_type_p = wilcox_type$p.value,
  wilcox_type_estimate_note = type_conf,
  cliffs_delta_solo_minus_group = delta_type,
  wilcox_sex_p = wilcox_sex$p.value,
  cliffs_delta_female_minus_male_solo = delta_sex,
  spearman_collab_rho = unname(spearman_collab$estimate),
  spearman_collab_p = spearman_collab$p.value,
  spearman_debut_rho = unname(spearman_debut$estimate),
  spearman_debut_p = spearman_debut$p.value,
  kruskal_genre_p = kruskal_genre$p.value,
  shapiro_total_p = shapiro_total$p.value,
  median_solo_artist = median(solo_vals),
  median_group_artist = median(group_vals)
)

write_csv_safe(numeric_distribution, "outputs/tables/numeric_distribution.csv")
write_csv_safe(tests, "outputs/tables/statistical_tests.csv")
write_csv_safe(concentration, "outputs/tables/concentration_metrics.csv")
write.csv(stream_cor, "outputs/tables/spearman_correlation_matrix.csv")
write_json(key_values, "outputs/reports/key_findings.json", pretty = TRUE, auto_unbox = TRUE)

fmt_p <- function(p) {
  if (p < 0.001) "< 0.001" else as.character(signif(p, 3))
}

findings_md <- c(
  "# Statistical Findings",
  "",
  paste("Generated:", key_values$generated_at),
  paste("N artists:", key_values$n_artists),
  "",
  "## Distribution of total streams",
  "",
  paste("- Sum of total streams in this catalog:", round(key_values$sum_total_streams_millions, 1), "million"),
  paste("- Mean:", round(key_values$mean_total, 1), "million; median:", round(key_values$median_total, 1), "million"),
  paste("- SD:", round(key_values$sd_total, 1), "; min:", round(key_values$min_total, 1), "; max:", round(key_values$max_total, 1)),
  paste("- Skewness (G1):", round(key_values$skewness_total, 3), "(right-skewed)"),
  paste("- Shapiro-Wilk p-value on raw totals:", fmt_p(key_values$shapiro_total_p)),
  paste("- IQR high outliers:", key_values$n_iqr_outliers, "artists above", round(key_values$iqr_upper, 1), "million"),
  "",
  "## Concentration",
  "",
  paste0("- Top 10 artists account for ", round(100 * key_values$top10_share, 2), "% of catalog total streams."),
  paste0("- Top 50 artists account for ", round(100 * key_values$top50_share, 2), "%."),
  paste0("- Top 100 artists account for ", round(100 * key_values$top100_share, 2), "%."),
  paste("- Gini coefficient of total streams:", round(key_values$gini, 4)),
  paste("- Leading artist:", key_values$leading_artist, "with", round(key_values$leading_artist_streams, 1), "million streams."),
  "",
  "## Solo versus collaborative streams",
  "",
  paste0("- Catalog-level solo share: ", round(100 * key_values$solo_stream_share, 2), "% of all streams."),
  paste0("- Catalog-level collaborative share: ", round(100 * key_values$collab_stream_share, 2), "% of all streams."),
  paste0("- Mean artist-level collaborative share: ", round(100 * key_values$mean_collab_share, 2), "%; median: ", round(100 * key_values$median_collab_share, 2), "%."),
  paste0("- Spearman rho (collaborative share vs total streams) = ", round(key_values$spearman_collab_rho, 4), ", p = ", fmt_p(key_values$spearman_collab_p), "."),
  "This is an association, not evidence that collaborating causes higher or lower totals.",
  "",
  "## Artist type",
  "",
  paste("- Solo artists:", key_values$n_solo, "; groups:", key_values$n_group),
  paste("- Median total streams, solo artists:", round(key_values$median_solo_artist, 1), "million"),
  paste("- Median total streams, groups:", round(key_values$median_group_artist, 1), "million"),
  paste("- Wilcoxon rank-sum p-value (solo vs group):", fmt_p(key_values$wilcox_type_p)),
  paste("-", key_values$wilcox_type_estimate_note),
  paste("- Cliff's delta (solo minus group):", round(key_values$cliffs_delta_solo_minus_group, 4)),
  "",
  "## Debut year",
  "",
  paste0("- Spearman rho (debut year vs total streams) = ", round(key_values$spearman_debut_rho, 4), ", p = ", fmt_p(key_values$spearman_debut_p), "."),
  "Debut year is the artist's start year, not the year streams were accumulated. Later debuts have had less calendar time, so any negative association should not be read as a causal career-quality effect.",
  "",
  "## Genre",
  "",
  paste("- Distinct genres:", key_values$n_genres, "; leading genre by summed streams:", key_values$leading_genre_by_sum),
  paste("- Kruskal-Wallis p-value across genres with n >= 10:", fmt_p(key_values$kruskal_genre_p)),
  "",
  "## Data-quality residual",
  "",
  paste("- Artists flagged for |lead + feature - total| > 0.5 million:", key_values$n_lead_feature_mismatch),
  "Solo + collaborative streams reconcile with total streams; lead + feature streams generally do not. Totals used in rankings come from the total-streams column.",
  "",
  "## Limitations",
  "",
  "- The file is a 500-artist snapshot, not a random sample of all Spotify artists.",
  "- Metrics are cumulative totals in millions of streams; they are not monthly rates.",
  "- Statistical tests describe this catalog only.",
  "- Multiple tests were run; p-values are descriptive diagnostics, not a pre-registered hypothesis set."
)

writeLines(findings_md, "outputs/reports/05_statistical_findings.md")
writeLines(findings_md, "reports/findings.md")
log_msg("Statistical analysis complete")
