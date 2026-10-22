# Power BI Data Model

This model is designed for a **single-grain artist table**. The R pipeline exports typed CSVs; Power BI Desktop is required to compile a `.pbix` file. Native Power BI Desktop is not assumed to be installed on Ubuntu.

## Recommended import

From `data/processed/` or the copies in `powerbi/`:

| CSV | Model table name | Grain | Role |
| --- | --- | --- | --- |
| `powerbi_artists.csv` | `Artists` | One row per artist | Primary fact/dimension table |
| `powerbi_genre.csv` | `GenreSummary` | One row per genre | Optional disconnected or related summary |
| `powerbi_country.csv` | `CountrySummary` | One row per country | Optional summary |
| `powerbi_language.csv` | `LanguageSummary` | One row per language | Optional summary |
| `powerbi_artist_type.csv` | `ArtistTypeSummary` | One row per artist type | Optional summary |
| `powerbi_debut_era.csv` | `DebutEraSummary` | Era × decade | Optional summary |
| `powerbi_quality.csv` | `QualityFlags` | One row per issue | Data-quality page |
| `powerbi_kpis.csv` | `PipelineKPIs` | One row per KPI | Static snapshot from R; optional |

**Minimum viable model:** import only `Artists` and create the measures in `measures.dax`. All six dashboard pages can be built from that table plus slicers.

## Relationships

If you import the summary tables, relate them as **one-to-many, single direction** from the summary key to `Artists`:

- `GenreSummary[primary_genre]` 1:* `Artists[primary_genre]`
- `CountrySummary[country_of_origin]` 1:* `Artists[country_of_origin]`
- `LanguageSummary[primary_language]` 1:* `Artists[primary_language]`
- `ArtistTypeSummary[artist_type]` 1:* `Artists[artist_type]`

Do **not** also SUM the pre-aggregated `total_streams_millions` on a summary table while a relationship is active and `Artists` is already being summed — that double-counts. Prefer measures on `Artists` and use summary tables only if you hide their numeric columns or mark them as disconnected.

`QualityFlags` and `PipelineKPIs` should remain **disconnected**.

## Column types

Set these types after import of `Artists`:

| Column | Type | Format |
| --- | --- | --- |
| `artist_name` | Text | — |
| `sex` | Text | — |
| `country_of_origin` | Text | — |
| `primary_language` | Text | — |
| `primary_genre` | Text | — |
| `artist_type` | Text | — |
| `debut_year` | Whole number | 0 |
| `debut_decade` | Whole number | 0 |
| `debut_era` | Text | — |
| `total_streams_millions` | Decimal | `#,0.0` |
| `lead_streams_millions` | Decimal | `#,0.0` |
| `feature_streams_millions` | Decimal | `#,0.0` |
| `solo_streams_millions` | Decimal | `#,0.0` |
| `collaborative_streams_millions` | Decimal | `#,0.0` |
| `solo_share` | Decimal | `0.00%` |
| `collaborative_share` | Decimal | `0.00%` |
| `lead_share` | Decimal | `0.00%` |
| `feature_share` | Decimal | `0.00%` |
| `catalog_share` | Decimal | `0.00%` |
| `artist_rank_total_streams` | Whole number | 0 |
| `flag_lead_feature_mismatch` | True/False | — |
| `flag_iqr_high_total` | True/False | — |
| `lead_feature_residual_millions` | Decimal | `#,0.00` |

## Aggregation rules

- Rankings and KPI totals use `total_streams_millions`.
- Solo vs collaborative mix uses `solo_streams_millions` and `collaborative_streams_millions`. These two columns reconcile to total streams in the source file.
- `lead_streams_millions` and `feature_streams_millions` do **not** generally sum to total streams. Do not hide that fact on the data-quality page.
- `solo_share` and `collaborative_share` are 0–1 proportions at artist grain. Catalog mix must use `DIVIDE(SUM(streams), SUM(total))`, not `AVERAGE(share)` unless you explicitly want an unweighted artist-level mean.
- Filter context: artist slicers should filter `Artists`. Rank measures use `ALLSELECTED` so ranks respect slicers but reset within the visible set.

## Sort columns

Create a sort column for `debut_era` if the text sort is wrong:

```dax
Debut Era Sort =
SWITCH (
    Artists[debut_era],
    "1939-1969", 1,
    "1970-1989", 2,
    "1990-1999", 3,
    "2000-2009", 4,
    "2010-2019", 5,
    "2020-2023", 6,
    9
)
```

Then: Column tools → Sort by column → `Debut Era Sort`.
