# Phase 6: publication-style ggplot2 charts from the processed dataset.

source("R/00_utils.R")
ensure_dirs()
log_msg("Starting visualizations")

artists <- readr::read_csv("data/processed/artists_features.csv", show_col_types = FALSE)
genre_summary <- readr::read_csv("outputs/tables/genre_summary.csv", show_col_types = FALSE)
country_summary <- readr::read_csv("outputs/tables/country_summary.csv", show_col_types = FALSE)
language_summary <- readr::read_csv("outputs/tables/language_summary.csv", show_col_types = FALSE)
debut_era_summary <- readr::read_csv("outputs/tables/debut_era_summary.csv", show_col_types = FALSE)
quality_summary <- readr::read_csv("outputs/tables/quality_summary.csv", show_col_types = FALSE)
keys <- jsonlite::fromJSON("outputs/reports/key_findings.json")

caption_source <- "Source: local Spotify Streaming Performance Dataset (500 artists). Stream units are millions."

top15 <- artists %>%
  slice_max(total_streams_millions, n = 15) %>%
  mutate(artist_name = fct_reorder(artist_name, total_streams_millions))

p_top_artists <- ggplot(top15, aes(total_streams_millions, artist_name)) +
  geom_col(fill = PALETTE$green, width = 0.72) +
  geom_text(
    aes(label = comma(round(total_streams_millions, 0))),
    hjust = 0,
    nudge_x = 1200,
    color = PALETTE$charcoal,
    size = 3.2
  ) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "A small set of catalog leaders accounts for the highest totals",
    subtitle = "Top 15 artists by total streams (millions)",
    x = "Total streams (millions)",
    y = NULL,
    caption = caption_source
  ) +
  editorial_theme() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#E4DCD0", linewidth = 0.3))
save_plot(p_top_artists, "01_top15_artists_total_streams", width = 11.5, height = 7.2)

genre_top <- genre_summary %>%
  slice_max(total_streams_millions, n = 12) %>%
  mutate(primary_genre = fct_reorder(primary_genre, total_streams_millions))

p_genre <- ggplot(genre_top, aes(total_streams_millions, primary_genre)) +
  geom_col(fill = PALETTE$green, width = 0.72) +
  geom_text(
    aes(label = paste0(comma(round(total_streams_millions, 0)), "  ·  n=", n_artists)),
    hjust = 0,
    nudge_x = 20000,
    color = PALETTE$charcoal,
    size = 3.1
  ) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.28))) +
  labs(
    title = "Hip-Hop and Pop lead the catalog by summed streams",
    subtitle = "Top 12 primary genres by total streams (millions); n is artist count",
    x = "Sum of total streams (millions)",
    y = NULL,
    caption = paste(caption_source, "Primary genre is a single label per artist.")
  ) +
  editorial_theme() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#E4DCD0", linewidth = 0.3))
save_plot(p_genre, "02_genre_total_streams", width = 11.5, height = 6.8)

country_top <- country_summary %>%
  slice_max(total_streams_millions, n = 12) %>%
  mutate(country_of_origin = fct_reorder(country_of_origin, total_streams_millions))

p_country <- ggplot(country_top, aes(total_streams_millions, country_of_origin)) +
  geom_col(fill = PALETTE$green_mid, width = 0.72) +
  geom_text(
    aes(label = paste0(comma(round(total_streams_millions, 0)), "  ·  n=", n_artists)),
    hjust = 0,
    nudge_x = 30000,
    color = PALETTE$charcoal,
    size = 3.1
  ) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.28))) +
  labs(
    title = "United States artists dominate catalog totals, with a long tail of markets",
    subtitle = "Top 12 countries of origin by summed total streams (millions)",
    x = "Sum of total streams (millions)",
    y = NULL,
    caption = paste(caption_source, "Country is origin, not current listening market.")
  ) +
  editorial_theme() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#E4DCD0", linewidth = 0.3))
save_plot(p_country, "03_country_total_streams", width = 11.5, height = 6.8)

solo_collab_long <- artists %>%
  summarise(
    Solo = sum(solo_streams_millions),
    Collaborative = sum(collaborative_streams_millions)
  ) %>%
  pivot_longer(everything(), names_to = "component", values_to = "streams_millions") %>%
  mutate(share = streams_millions / sum(streams_millions), component = fct_rev(component))

p_solo_collab <- ggplot(solo_collab_long, aes(component, streams_millions, fill = component)) +
  geom_col(width = 0.55) +
  geom_text(
    aes(label = paste0(comma(round(streams_millions, 0)), "\n", percent(share, accuracy = 0.1))),
    vjust = -0.2,
    color = PALETTE$charcoal,
    size = 3.6
  ) +
  scale_fill_manual(values = c(Solo = PALETTE$green, Collaborative = PALETTE$warm), guide = "none") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.16))) +
  labs(
    title = "Solo and collaborative streams are nearly even at catalog level",
    subtitle = "Sum of solo versus collaborative streams across 500 artists (millions)",
    x = NULL,
    y = "Streams (millions)",
    caption = paste(caption_source, "These two components reconcile to total streams.")
  ) +
  editorial_theme()
save_plot(p_solo_collab, "04_solo_vs_collaborative_totals", width = 10, height = 6.4)

p_type <- ggplot(artists, aes(artist_type, total_streams_millions, fill = artist_type)) +
  geom_boxplot(width = 0.45, outlier.alpha = 0.45, outlier.size = 1.6, color = PALETTE$charcoal) +
  scale_fill_manual(values = c(Solo = PALETTE$green_light, Group = PALETTE$green), guide = "none") +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Typical group totals sit near typical solo totals; a few solo artists stretch the upper tail",
    subtitle = "Distribution of artist-level total streams (millions) by artist type",
    x = NULL,
    y = "Total streams (millions)",
    caption = paste(caption_source, "Boxes show medians and quartiles; points are artists.")
  ) +
  editorial_theme() +
  theme(panel.grid.major.x = element_blank())
save_plot(p_type, "05_artist_type_boxplot", width = 10.5, height = 6.6)

p_collab_scatter <- ggplot(artists, aes(collaborative_share, total_streams_millions)) +
  geom_point(aes(color = artist_type), alpha = 0.7, size = 2.2) +
  geom_smooth(method = "loess", se = TRUE, color = PALETTE$charcoal, fill = PALETTE$green_light, linewidth = 0.7) +
  scale_color_manual(values = c(Solo = PALETTE$green, Group = PALETTE$warm), name = "Artist type") +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Higher collaboration share is only weakly related to higher totals",
    subtitle = paste0(
      "Each point is an artist. Spearman rho = ",
      round(keys$spearman_collab_rho, 3),
      " (p = ",
      ifelse(keys$spearman_collab_p < 0.001, "< 0.001", signif(keys$spearman_collab_p, 3)),
      ")"
    ),
    x = "Collaborative share of the artist's streams",
    y = "Total streams (millions)",
    caption = paste(caption_source, "The smoother is descriptive; it is not a causal model.")
  ) +
  editorial_theme()
save_plot(p_collab_scatter, "06_collaboration_share_vs_total", width = 11, height = 6.8)

era_order <- c("1939-1969", "1970-1989", "1990-1999", "2000-2009", "2010-2019", "2020-2023")
era_plot <- debut_era_summary %>%
  mutate(debut_era = factor(debut_era, levels = era_order))

p_era <- ggplot(era_plot, aes(debut_era, median_streams_millions)) +
  geom_col(fill = PALETTE$green, width = 0.62) +
  geom_text(aes(label = paste0(comma(round(median_streams_millions, 0)), "\nn=", n_artists)), vjust = -0.15, size = 3.2, color = PALETTE$charcoal) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "Median totals are highest among 1990s and 2000s debuts in this snapshot",
    subtitle = "Median artist total streams (millions) by debut-year era",
    x = "Debut era",
    y = "Median total streams (millions)",
    caption = paste(caption_source, "Cumulative totals favor artists with more years in the catalog; this is not a debut-year causal effect.")
  ) +
  editorial_theme()
save_plot(p_era, "07_debut_era_median_streams", width = 11, height = 6.6)

lang_top <- language_summary %>%
  mutate(primary_language = fct_reorder(primary_language, total_streams_millions))

p_lang <- ggplot(lang_top, aes(total_streams_millions, primary_language)) +
  geom_col(fill = PALETTE$green_mid, width = 0.72) +
  geom_text(
    aes(label = paste0(comma(round(total_streams_millions, 0)), "  ·  n=", n_artists)),
    hjust = 0,
    nudge_x = 40000,
    size = 3.1,
    color = PALETTE$charcoal
  ) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.32))) +
  labs(
    title = "English-language artists contribute the largest share of catalog streams",
    subtitle = "Primary language by summed total streams (millions)",
    x = "Sum of total streams (millions)",
    y = NULL,
    caption = paste(caption_source, "Primary language is a single label per artist.")
  ) +
  editorial_theme() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#E4DCD0", linewidth = 0.3))
save_plot(p_lang, "08_language_total_streams", width = 11.5, height = 6.5)

p_dist <- ggplot(artists, aes(total_streams_millions)) +
  geom_histogram(bins = 30, fill = PALETTE$green, color = "#F6F1E9", linewidth = 0.3) +
  geom_vline(xintercept = median(artists$total_streams_millions), color = PALETTE$warm, linewidth = 0.9) +
  annotate(
    "text",
    x = median(artists$total_streams_millions) + 8000,
    y = Inf,
    vjust = 1.5,
    hjust = 0,
    label = paste("Median", round(median(artists$total_streams_millions), 0)),
    color = PALETTE$warm,
    size = 3.3
  ) +
  scale_x_continuous(labels = comma) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(
    title = "Streaming totals are right-skewed: most artists cluster well below the catalog leaders",
    subtitle = "Distribution of artist-level total streams (millions)",
    x = "Total streams (millions)",
    y = "Number of artists",
    caption = caption_source
  ) +
  editorial_theme()
save_plot(p_dist, "09_total_streams_distribution", width = 11, height = 6.4)

quality_plot <- quality_summary %>%
  mutate(metric_label = str_replace_all(metric, "_", " ")) %>%
  arrange(value, metric_label) %>%
  mutate(metric_label = factor(metric_label, levels = unique(metric_label)))

p_quality <- ggplot(quality_plot, aes(value, metric_label)) +
  geom_col(fill = PALETTE$alert, width = 0.7) +
  geom_text(aes(label = comma(value)), hjust = 0, nudge_x = 5, size = 3.2, color = PALETTE$charcoal) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "The main data-quality issue is lead-plus-feature residual, not missingness",
    subtitle = "Quality flags and structural counts from the 500-artist file",
    x = "Count",
    y = NULL,
    caption = paste(caption_source, "Missing cells and duplicate artists are zero.")
  ) +
  editorial_theme() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#E4DCD0", linewidth = 0.3))
save_plot(p_quality, "10_data_quality_flags", width = 11, height = 6.2)

manifest <- tibble(
  chart = c(
    "01_top15_artists_total_streams",
    "02_genre_total_streams",
    "03_country_total_streams",
    "04_solo_vs_collaborative_totals",
    "05_artist_type_boxplot",
    "06_collaboration_share_vs_total",
    "07_debut_era_median_streams",
    "08_language_total_streams",
    "09_total_streams_distribution",
    "10_data_quality_flags"
  ),
  question = c(
    "Which artists have the highest total streams?",
    "Which genres contribute the most catalog streams?",
    "Which origin countries contribute the most catalog streams?",
    "How do solo and collaborative streams compare in aggregate?",
    "Do solo artists and groups differ in typical totals?",
    "How does collaboration share relate to total streams?",
    "How do median totals vary by debut era?",
    "Which primary languages contribute the most catalog streams?",
    "How are total streams distributed, and where are outliers?",
    "What data-quality issues appear in this file?"
  )
)
write_csv_safe(manifest, "outputs/tables/figure_manifest.csv")
log_msg("Visualizations complete")
