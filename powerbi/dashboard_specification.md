# Power BI Dashboard Specification

**File to create on Windows / Power BI Desktop:** `powerbi/MusicStreamingAnalytics.pbix`  
This Ubuntu environment does not include Power BI Desktop. The `.pbix` file is **not** produced here. R preview charts in `outputs/figures/` show the same questions with the same data.

**Theme:** warm off-white background `#F6F1E9`, charcoal text `#2C2C2C`, green accent `#3D6B5A`, secondary warm `#C17F4A`. Avoid neon palettes, 3D, and dense KPI walls.

**Navigation:** six pages in a top button row or the built-in page tabs, identically placed on every page.

**Global slicers (Pages 1–5):** `artist_type`, `primary_genre`, `country_of_origin`, `primary_language`, `debut_era`. Sync slicers across pages 1–5. Do **not** put these slicers on Page 6 except as a documentation note.

**Source table:** `Artists` from `powerbi_artists.csv`. Measures: see `measures.dax`.

---

## Page 1 — Executive Overview

**Question:** How large is this catalog, who leads it, and how concentrated are streams?

| Visual | Type | Fields / measures | Notes |
| --- | --- | --- | --- |
| Total streams | Card | `[Total Streams (M)]` | Format millions with one decimal |
| Distinct artists | Card | `[Distinct Artists]` | Should be 500 with no slicers |
| Distinct genres | Card | `[Distinct Genres]` | |
| Distinct countries | Card | `[Distinct Countries]` | |
| Leading artist | Card | `[Leading Artist]` | |
| Leading genre | Card | `[Leading Genre]` | |
| Distribution | Histogram or box-and-whisker | `Artists[total_streams_millions]` | Show skew; tooltip: artist name |
| Top 10 artists | Horizontal bar | Axis: `artist_name`; Values: `[Total Streams (M)]` | Sort descending; Top N = 10 |
| Key findings text | Text box | Static, from `reports/findings.md` | Distinguish association vs causation |

Tooltip on bars: artist, genre, country, solo share, collaborative share.

---

## Page 2 — Artist Performance

**Question:** How do individual artists compare across stream components?

| Visual | Type | Fields / measures |
| --- | --- | --- |
| Artist search | Slicer, search enabled | `Artists[artist_name]` |
| Ranked table | Table | `artist_name`, `[Artist Rank by Total Streams]`, `[Total Streams (M)]`, `[Solo Streams (M)]`, `[Collaborative Streams (M)]`, `[Lead Streams (M)]`, `[Feature Streams (M)]`, `[Solo Share]`, `[Collaboration Share]` |
| Component comparison | Clustered bar | Values: the four stream measures; legend: component; axis: `artist_name` (Top N 15) |
| Catalog contribution | Bar | `[Percentage Contribution to Visible Total]` |

Do not add lead + feature into a “reconstructed total” column without showing the residual.

---

## Page 3 — Genre and Market Analysis

**Question:** Which genres, origin countries, and languages carry catalog streams?

| Visual | Type | Fields / measures |
| --- | --- | --- |
| Genre bars | Horizontal bar | Axis: `primary_genre`; `[Total Streams (M)]`; tooltip `[Distinct Artists]` |
| Country bars | Horizontal bar | Axis: `country_of_origin`; `[Total Streams (M)]` |
| Language bars | Horizontal bar | Axis: `primary_language`; `[Total Streams (M)]` |
| Genre vs median | Scatter | X: `[Distinct Artists]` (per genre, use a genre-level visual); Y: `[Median Streams per Artist (M)]` |

Cross-filter: clicking a genre should filter country and language visuals via the `Artists` table.

Country is **origin**, not listening market. Language is a single primary label.

---

## Page 4 — Collaboration Insights

**Question:** How do solo and collaborative streams compare, and how does collaboration share relate to totals?

| Visual | Type | Fields / measures |
| --- | --- | --- |
| Mix cards | Cards | `[Solo Streams (M)]`, `[Collaborative Streams (M)]`, `[Solo Share]`, `[Collaboration Share]` |
| Artist scatter | Scatter | X: `Artists[collaborative_share]`; Y: `Artists[total_streams_millions]`; legend: `artist_type`; tooltip: name |
| Type comparison | Box plot or clustered bar | `[Median Streams per Artist (M)]` by `artist_type` |
| High-collab table | Table | Filter `collaborative_share` ≥ 0.75; show name, genre, totals |

Title/footnote: Spearman association is documented in `reports/findings.md`. Do not title the scatter as a causal effect.

---

## Page 5 — Artist Lifecycle

**Question:** How do cumulative totals vary by debut era in this snapshot?

| Visual | Type | Fields / measures |
| --- | --- | --- |
| Era bars | Column | Axis: `debut_era` (sorted); `[Median Streams per Artist (M)]` and `[Distinct Artists]` |
| Decade trend | Line or column | Axis: `debut_decade`; `[Total Streams (M)]` |
| Era table | Table | `debut_era`, `[Distinct Artists]`, `[Total Streams (M)]`, `[Median Streams per Artist (M)]`, `[Collaboration Share]` |

**Required footnote:** Totals are cumulative. Earlier debuts have had more time. This page does not show streams earned in each year.

---

## Page 6 — Data Quality and Methodology

**Question:** What should a reader distrust or qualify?

| Visual | Type | Fields / measures |
| --- | --- | --- |
| Quality cards | Cards | `[Mismatch Artists (Lead+Feature)]`, `[IQR Outlier Artists]`, `[Distinct Artists]` |
| Residual distribution | Histogram | `lead_feature_residual_millions` |
| Flag table | Table | `QualityFlags` disconnected table, or `Artists` filtered to mismatch |
| Metric definitions | Text box | Copy from `docs/data-dictionary.md` |
| Limitations | Text box | 500-artist catalog; not a random sample; no user-level behavior; no causal claims |

---

## Rebuild steps in Power BI Desktop

1. Open Power BI Desktop on Windows (or another supported host).
2. Get data → Text/CSV → `data/processed/powerbi_artists.csv` → Load.
3. Optionally import the other `powerbi_*.csv` files.
4. In Model view, set types and formats from `data_model.md`.
5. In Report view, New measure → paste each measure from `measures.dax` (one at a time, without the comment blocks if the editor rejects them).
6. Create six pages with the visuals above.
7. View → Sync slicers for pages 1–5.
8. File → Save as `MusicStreamingAnalytics.pbix`.

## Preview charts already generated in R

Use these as layout and color references:

- `outputs/figures/01_top15_artists_total_streams.png`
- `outputs/figures/02_genre_total_streams.png`
- `outputs/figures/03_country_total_streams.png`
- `outputs/figures/04_solo_vs_collaborative_totals.png`
- `outputs/figures/05_artist_type_boxplot.png`
- `outputs/figures/06_collaboration_share_vs_total.png`
- `outputs/figures/07_debut_era_median_streams.png`
- `outputs/figures/08_language_total_streams.png`
- `outputs/figures/09_total_streams_distribution.png`
- `outputs/figures/10_data_quality_flags.png`
