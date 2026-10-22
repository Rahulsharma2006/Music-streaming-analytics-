# Data Audit Report

Generated: 2026-10-22 16:32:22 UTC
Source file: data/raw/Spotify Streaming Performance Dataset.csv

## Shape and grain

- Rows: 500
- Columns: 14
- Unique artist names: 500
- Duplicate rows: 0
- Duplicate artist names: 0
- Dataset grain: One row per artist name; 500 unique artist names in 500 rows.
- Missing cells: 0

## Raw header

`Artist Name,Sex,Country of Origin,Primary Language,Primary Genre, Artist Type,Debut Year,Total Streams (in millions),Lead Streams (in millions),Feature Streams (in millions),Solo Streams (in millions),% of Solo Streams,Collaborative Streams (in millions),% of Collaborative Streams`

## Reconciliation

- Max |solo + collaborative - total|: 0.00000000000727596
- Artists with |lead + feature - total| > 0.01 million: 425
- Artists with |lead + feature - total| > 1 million: 397
- Max |lead + feature - total|: 89.2 million streams
- Percentage values outside 0-100: 0

## Concentration (total streams)

- Top 10 artists share: 10.62%
- Top 50 artists share: 30.59%
- Top 100 artists share: 45.91%
- Gini coefficient: 0.3564
- IQR high outliers (total streams > Q3 + 1.5 IQR): 49
- IQR upper bound: 31897.86 million

## Notes

- The raw header contains a leading space before 'Artist Type'; readr/str_squish normalizes the name.
- All stream columns are labeled in millions.
- Solo + collaborative streams reconcile to total streams within floating-point error.
- Lead + feature streams do not reconcile to total streams for most artists.
- Reported solo/collaborative percentages match the corresponding stream ratios.
- No missing values and no duplicate artist names were observed.
- Scotland is recorded separately from United Kingdom; labels were left unchanged.
