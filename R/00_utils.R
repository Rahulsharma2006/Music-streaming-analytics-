# Shared helpers for the Music Streaming Analytics pipeline.
# All scripts should be executed with the project root as the working directory.

Sys.setenv(TZ = "UTC")
options(stringsAsFactors = FALSE, scipen = 999)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(ggplot2)
  library(janitor)
  library(scales)
  library(purrr)
  library(tibble)
  library(forcats)
  library(broom)
  library(jsonlite)
})

RAW_DATA_PATH <- file.path("data", "raw", "Spotify Streaming Performance Dataset.csv")

REQUIRED_ORIGINAL_COLUMNS <- c(
  "Artist Name",
  "Sex",
  "Country of Origin",
  "Primary Language",
  "Primary Genre",
  "Artist Type",
  "Debut Year",
  "Total Streams (in millions)",
  "Lead Streams (in millions)",
  "Feature Streams (in millions)",
  "Solo Streams (in millions)",
  "% of Solo Streams",
  "Collaborative Streams (in millions)",
  "% of Collaborative Streams"
)

COLUMN_NAME_MAP <- tibble::tribble(
  ~original_name, ~cleaned_name,
  "Artist Name", "artist_name",
  "Sex", "sex",
  "Country of Origin", "country_of_origin",
  "Primary Language", "primary_language",
  "Primary Genre", "primary_genre",
  "Artist Type", "artist_type",
  "Debut Year", "debut_year",
  "Total Streams (in millions)", "total_streams_millions",
  "Lead Streams (in millions)", "lead_streams_millions",
  "Feature Streams (in millions)", "feature_streams_millions",
  "Solo Streams (in millions)", "solo_streams_millions",
  "% of Solo Streams", "pct_of_solo_streams",
  "Collaborative Streams (in millions)", "collaborative_streams_millions",
  "% of Collaborative Streams", "pct_of_collaborative_streams"
)

ensure_dirs <- function() {
  dirs <- c(
    "data/processed",
    "data/reference",
    "outputs/figures",
    "outputs/reports",
    "outputs/tables",
    "logs",
    "docs",
    "powerbi",
    "tests/fixtures",
    "reports"
  )
  walk(dirs, ~ dir.create(.x, recursive = TRUE, showWarnings = FALSE))
}

project_stamp <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
}

log_msg <- function(...) {
  msg <- paste0("[", project_stamp(), "] ", paste(..., collapse = " "))
  cat(msg, "\n")
}

write_csv_safe <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path, na = "")
  invisible(path)
}

gini_coefficient <- function(x) {
  x <- x[is.finite(x) & !is.na(x)]
  stopifnot(length(x) > 0, all(x >= 0))
  if (sum(x) == 0) return(0)
  x <- sort(x)
  n <- length(x)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}

share_of_total <- function(x, n_top) {
  x <- sort(x[is.finite(x)], decreasing = TRUE)
  sum(x[seq_len(min(n_top, length(x)))]) / sum(x)
}

iqr_bounds <- function(x) {
  q <- stats::quantile(x, probs = c(0.25, 0.75), na.rm = TRUE, names = FALSE)
  iqr <- q[2] - q[1]
  list(q1 = q[1], q3 = q[2], iqr = iqr, lower = q[1] - 1.5 * iqr, upper = q[2] + 1.5 * iqr)
}

skewness_g1 <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  m <- mean(x)
  s <- sd(x)
  if (n < 3 || s == 0) return(NA_real_)
  (n / ((n - 1) * (n - 2))) * sum(((x - m) / s)^3)
}

kurtosis_g2 <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  m <- mean(x)
  s <- sd(x)
  if (n < 4 || s == 0) return(NA_real_)
  z <- (x - m) / s
  term <- sum(z^4) * n * (n + 1) / ((n - 1) * (n - 2) * (n - 3))
  adj <- 3 * (n - 1)^2 / ((n - 2) * (n - 3))
  term - adj
}

rank_biserial_from_wilcox <- function(wilcox_obj, n1, n2) {
  # Effect size r = Z / sqrt(N) using the Wilcoxon two-sample statistic.
  z <- wilcox_obj$statistic
  # wilcox.test with exact=FALSE returns W; convert via p-value normal approx.
  p <- wilcox_obj$p.value
  z_from_p <- stats::qnorm(p / 2, lower.tail = FALSE)
  if (!is.null(wilcox_obj$alternative) && identical(wilcox_obj$alternative, "two.sided")) {
    # sign is not recovered from two-sided p; report magnitude only from p.
  }
  r <- z_from_p / sqrt(n1 + n2)
  r
}

cliffs_delta <- function(x, y) {
  x <- x[is.finite(x)]
  y <- y[is.finite(y)]
  n1 <- length(x)
  n2 <- length(y)
  if (n1 == 0 || n2 == 0) return(NA_real_)
  gt <- sum(outer(x, y, ">"))
  lt <- sum(outer(x, y, "<"))
  (gt - lt) / (n1 * n2)
}

debut_era <- function(year) {
  dplyr::case_when(
    year < 1970 ~ "1939-1969",
    year < 1990 ~ "1970-1989",
    year < 2000 ~ "1990-1999",
    year < 2010 ~ "2000-2009",
    year < 2020 ~ "2010-2019",
    TRUE ~ "2020-2023"
  )
}

editorial_theme <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#F6F1E9", color = NA),
      panel.background = ggplot2::element_rect(fill = "#F6F1E9", color = NA),
      panel.grid.major.y = ggplot2::element_line(color = "#E4DCD0", linewidth = 0.3),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(color = "#2C2C2C", face = "bold", size = base_size + 3, margin = ggplot2::margin(b = 6)),
      plot.subtitle = ggplot2::element_text(color = "#6B6560", size = base_size, margin = ggplot2::margin(b = 12)),
      plot.caption = ggplot2::element_text(color = "#8A837A", size = base_size - 2, hjust = 0, margin = ggplot2::margin(t = 10)),
      axis.title = ggplot2::element_text(color = "#4A4540"),
      axis.text = ggplot2::element_text(color = "#4A4540"),
      axis.ticks = ggplot2::element_blank(),
      legend.position = "top",
      legend.title = ggplot2::element_text(color = "#4A4540"),
      legend.text = ggplot2::element_text(color = "#4A4540"),
      legend.background = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(16, 20, 14, 16)
    )
}

PALETTE <- list(
  green = "#3D6B5A",
  green_mid = "#5E8A74",
  green_light = "#A9C4B5",
  charcoal = "#2C2C2C",
  warm = "#C17F4A",
  muted = "#8A837A",
  alert = "#8C4A3A"
)

save_plot <- function(plot, name, width = 11, height = 6.5) {
  png_path <- file.path("outputs", "figures", paste0(name, ".png"))
  pdf_path <- file.path("outputs", "figures", paste0(name, ".pdf"))
  ggplot2::ggsave(png_path, plot, width = width, height = height, dpi = 200, bg = "#F6F1E9")
  ggplot2::ggsave(pdf_path, plot, width = width, height = height, device = "pdf", bg = "#F6F1E9")
  invisible(list(png = png_path, pdf = pdf_path))
}

read_raw_dataset <- function(path = RAW_DATA_PATH) {
  if (!file.exists(path)) {
    stop("Raw dataset not found at: ", path)
  }
  # readr trims header whitespace, which removes the leading space on " Artist Type".
  df <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_guess()),
    trim_ws = TRUE,
    show_col_types = FALSE,
    progress = FALSE
  )
  names(df) <- stringr::str_squish(names(df))
  missing_cols <- setdiff(REQUIRED_ORIGINAL_COLUMNS, names(df))
  extra_cols <- setdiff(names(df), REQUIRED_ORIGINAL_COLUMNS)
  if (length(missing_cols) > 0) {
    stop("Missing expected columns: ", paste(missing_cols, collapse = ", "))
  }
  if (length(extra_cols) > 0) {
    warning("Unexpected extra columns: ", paste(extra_cols, collapse = ", "))
  }
  df
}

rename_to_clean <- function(df) {
  lookup <- COLUMN_NAME_MAP$cleaned_name
  names(lookup) <- COLUMN_NAME_MAP$original_name
  unknown <- setdiff(names(df), names(lookup))
  if (length(unknown) > 0) {
    stop("Cannot rename columns not in mapping: ", paste(unknown, collapse = ", "))
  }
  names(df) <- unname(lookup[names(df)])
  df
}
