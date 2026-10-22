# Phase 1: audit the raw CSV without mutating it.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting data audit")

raw <- read_raw_dataset()
raw_header <- readLines(RAW_DATA_PATH, n = 1, encoding = "UTF-8")

n_rows <- nrow(raw)
n_cols <- ncol(raw)
n_artists <- dplyr::n_distinct(raw[["Artist Name"]])
n_dup_rows <- sum(duplicated(raw))
n_dup_artists <- sum(duplicated(raw[["Artist Name"]]))

type_tbl <- tibble(
  original_name = names(raw),
  r_class = vapply(raw, function(x) paste(class(x), collapse = "/"), character(1)),
  n_missing = colSums(is.na(raw)),
  n_blank = vapply(raw, function(x) {
    if (is.character(x)) as.integer(sum(x == "" | is.na(x))) else NA_integer_
  }, integer(1)),
  n_distinct = vapply(raw, function(x) as.integer(dplyr::n_distinct(x)), integer(1))
) %>%
  left_join(COLUMN_NAME_MAP, by = "original_name")

numeric_cols <- names(raw)[vapply(raw, is.numeric, logical(1))]
numeric_summary <- map_dfr(numeric_cols, function(col) {
  x <- raw[[col]]
  tibble(
    original_name = col,
    min = min(x, na.rm = TRUE),
    q1 = as.numeric(quantile(x, 0.25, na.rm = TRUE)),
    median = median(x, na.rm = TRUE),
    mean = mean(x, na.rm = TRUE),
    q3 = as.numeric(quantile(x, 0.75, na.rm = TRUE)),
    max = max(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    n_negative = sum(x < 0, na.rm = TRUE),
    n_zero = sum(x == 0, na.rm = TRUE)
  )
})

tot <- raw[["Total Streams (in millions)"]]
lead <- raw[["Lead Streams (in millions)"]]
feat <- raw[["Feature Streams (in millions)"]]
solo <- raw[["Solo Streams (in millions)"]]
collab <- raw[["Collaborative Streams (in millions)"]]
pct_solo <- raw[["% of Solo Streams"]]
pct_collab <- raw[["% of Collaborative Streams"]]

solo_collab_diff <- solo + collab - tot
lead_feat_diff <- lead + feat - tot
pct_sum_diff <- pct_solo + pct_collab - 100
pct_vs_ratio_diff <- (solo / tot) * 100 - pct_solo

recon <- tibble(
  check = c(
    "solo_plus_collaborative_minus_total",
    "lead_plus_feature_minus_total",
    "pct_solo_plus_pct_collab_minus_100",
    "implied_solo_pct_minus_reported_pct"
  ),
  max_abs_diff = c(
    max(abs(solo_collab_diff)),
    max(abs(lead_feat_diff)),
    max(abs(pct_sum_diff)),
    max(abs(pct_vs_ratio_diff))
  ),
  n_abs_gt_0_01 = c(
    sum(abs(solo_collab_diff) > 0.01),
    sum(abs(lead_feat_diff) > 0.01),
    sum(abs(pct_sum_diff) > 0.01),
    sum(abs(pct_vs_ratio_diff) > 0.01)
  ),
  n_abs_gt_1 = c(
    sum(abs(solo_collab_diff) > 1),
    sum(abs(lead_feat_diff) > 1),
    sum(abs(pct_sum_diff) > 1),
    sum(abs(pct_vs_ratio_diff) > 1)
  )
)

lead_feat_flags <- tibble(
  artist_name = raw[["Artist Name"]],
  total_streams_millions = tot,
  lead_plus_feature_minus_total = lead_feat_diff
) %>%
  arrange(desc(abs(lead_plus_feature_minus_total)))

iqr_tot <- iqr_bounds(tot)
outlier_artists <- raw %>%
  transmute(
    artist_name = `Artist Name`,
    total_streams_millions = tot,
    is_high_outlier = tot > iqr_tot$upper
  ) %>%
  filter(is_high_outlier) %>%
  arrange(desc(total_streams_millions))

categoricals <- list(
  Sex = table(raw$Sex, useNA = "ifany"),
  `Artist Type` = table(raw[["Artist Type"]], useNA = "ifany"),
  `Primary Genre` = sort(table(raw[["Primary Genre"]], useNA = "ifany"), decreasing = TRUE),
  `Country of Origin` = sort(table(raw[["Country of Origin"]], useNA = "ifany"), decreasing = TRUE),
  `Primary Language` = sort(table(raw[["Primary Language"]], useNA = "ifany"), decreasing = TRUE)
)

write_csv_safe(type_tbl, "outputs/tables/audit_column_profile.csv")
write_csv_safe(numeric_summary, "outputs/tables/audit_numeric_summary.csv")
write_csv_safe(recon, "outputs/tables/audit_reconciliation.csv")
write_csv_safe(lead_feat_flags, "outputs/tables/audit_lead_feature_residual.csv")
write_csv_safe(outlier_artists, "outputs/tables/audit_total_stream_iqr_outliers.csv")
write_csv_safe(COLUMN_NAME_MAP, "data/reference/column_mapping.csv")

counts_tbl <- bind_rows(
  tibble(variable = "Sex", value = names(categoricals$Sex), n = as.integer(categoricals$Sex)),
  tibble(variable = "Artist Type", value = names(categoricals$`Artist Type`), n = as.integer(categoricals$`Artist Type`)),
  tibble(variable = "Primary Genre", value = names(categoricals$`Primary Genre`), n = as.integer(categoricals$`Primary Genre`)),
  tibble(variable = "Country of Origin", value = names(categoricals$`Country of Origin`), n = as.integer(categoricals$`Country of Origin`)),
  tibble(variable = "Primary Language", value = names(categoricals$`Primary Language`), n = as.integer(categoricals$`Primary Language`))
)
write_csv_safe(counts_tbl, "outputs/tables/audit_categorical_counts.csv")

audit <- list(
  generated_at = project_stamp(),
  source_file = RAW_DATA_PATH,
  raw_header = raw_header,
  n_rows = n_rows,
  n_cols = n_cols,
  grain = "One row per artist name; 500 unique artist names in 500 rows.",
  n_unique_artists = n_artists,
  n_duplicate_rows = n_dup_rows,
  n_duplicate_artist_names = n_dup_artists,
  n_missing_cells = as.integer(sum(colSums(is.na(raw)))),
  debut_year_min = min(raw[["Debut Year"]]),
  debut_year_max = max(raw[["Debut Year"]]),
  total_streams_sum_millions = sum(tot),
  total_streams_median = median(tot),
  total_streams_mean = mean(tot),
  top10_share = share_of_total(tot, 10),
  top50_share = share_of_total(tot, 50),
  top100_share = share_of_total(tot, 100),
  gini_total_streams = gini_coefficient(tot),
  n_iqr_high_outliers = nrow(outlier_artists),
  iqr_upper_bound = iqr_tot$upper,
  n_lead_feature_residual_gt_0_01 = sum(abs(lead_feat_diff) > 0.01),
  n_lead_feature_residual_gt_1 = sum(abs(lead_feat_diff) > 1),
  max_abs_lead_feature_residual = max(abs(lead_feat_diff)),
  max_abs_solo_collab_residual = max(abs(solo_collab_diff)),
  pct_outside_0_100 = sum(pct_solo < 0 | pct_solo > 100 | pct_collab < 0 | pct_collab > 100),
  notes = c(
    "The raw header contains a leading space before 'Artist Type'; readr/str_squish normalizes the name.",
    "All stream columns are labeled in millions.",
    "Solo + collaborative streams reconcile to total streams within floating-point error.",
    "Lead + feature streams do not reconcile to total streams for most artists.",
    "Reported solo/collaborative percentages match the corresponding stream ratios.",
    "No missing values and no duplicate artist names were observed.",
    "Scotland is recorded separately from United Kingdom; labels were left unchanged."
  )
)

write_json(audit, "outputs/reports/audit_summary.json", pretty = TRUE, auto_unbox = TRUE)

md <- c(
  "# Data Audit Report",
  "",
  paste("Generated:", audit$generated_at),
  paste("Source file:", audit$source_file),
  "",
  "## Shape and grain",
  "",
  paste("- Rows:", n_rows),
  paste("- Columns:", n_cols),
  paste("- Unique artist names:", n_artists),
  paste("- Duplicate rows:", n_dup_rows),
  paste("- Duplicate artist names:", n_dup_artists),
  paste("- Dataset grain:", audit$grain),
  paste("- Missing cells:", audit$n_missing_cells),
  "",
  "## Raw header",
  "",
  paste0("`", raw_header, "`"),
  "",
  "## Reconciliation",
  "",
  paste("- Max |solo + collaborative - total|:", signif(audit$max_abs_solo_collab_residual, 6)),
  paste("- Artists with |lead + feature - total| > 0.01 million:", audit$n_lead_feature_residual_gt_0_01),
  paste("- Artists with |lead + feature - total| > 1 million:", audit$n_lead_feature_residual_gt_1),
  paste("- Max |lead + feature - total|:", round(audit$max_abs_lead_feature_residual, 3), "million streams"),
  paste("- Percentage values outside 0-100:", audit$pct_outside_0_100),
  "",
  "## Concentration (total streams)",
  "",
  paste0("- Top 10 artists share: ", round(100 * audit$top10_share, 2), "%"),
  paste0("- Top 50 artists share: ", round(100 * audit$top50_share, 2), "%"),
  paste0("- Top 100 artists share: ", round(100 * audit$top100_share, 2), "%"),
  paste0("- Gini coefficient: ", round(audit$gini_total_streams, 4)),
  paste("- IQR high outliers (total streams > Q3 + 1.5 IQR):", audit$n_iqr_high_outliers),
  paste("- IQR upper bound:", round(audit$iqr_upper_bound, 2), "million"),
  "",
  "## Notes",
  "",
  paste("-", audit$notes)
)

writeLines(md, "outputs/reports/01_data_audit.md")
log_msg("Data audit complete")
