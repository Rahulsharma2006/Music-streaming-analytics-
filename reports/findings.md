# Statistical Findings

Generated: 2026-10-22 16:32:25 UTC
N artists: 500

## Distribution of total streams

- Sum of total streams in this catalog: 8408805.1 million
- Mean: 16817.6 million; median: 11923.2 million
- SD: 14845.2 ; min: 6972 ; max: 137492.1
- Skewness (G1): 3.998 (right-skewed)
- Shapiro-Wilk p-value on raw totals: < 0.001
- IQR high outliers: 49 artists above 31897.9 million

## Concentration

- Top 10 artists account for 10.62% of catalog total streams.
- Top 50 artists account for 30.59%.
- Top 100 artists account for 45.91%.
- Gini coefficient of total streams: 0.3564
- Leading artist: Drake with 137492.1 million streams.

## Solo versus collaborative streams

- Catalog-level solo share: 49.5% of all streams.
- Catalog-level collaborative share: 50.5% of all streams.
- Mean artist-level collaborative share: 49.39%; median: 52.94%.
- Spearman rho (collaborative share vs total streams) = 0.0624, p = 0.163.
This is an association, not evidence that collaborating causes higher or lower totals.

## Artist type

- Solo artists: 373 ; groups: 127
- Median total streams, solo artists: 12700.7 million
- Median total streams, groups: 10607 million
- Wilcoxon rank-sum p-value (solo vs group): 0.00154
- Hodges-Lehmann median difference (Solo - Group) = 1411.6 million; 95% CI [485.1, 2565]
- Cliff's delta (solo minus group): 0.188

## Debut year

- Spearman rho (debut year vs total streams) = 0.0125, p = 0.781.
Debut year is the artist's start year, not the year streams were accumulated. Later debuts have had less calendar time, so any negative association should not be read as a causal career-quality effect.

## Genre

- Distinct genres: 23 ; leading genre by summed streams: Hip-Hop
- Kruskal-Wallis p-value across genres with n >= 10: 0.0549

## Data-quality residual

- Artists flagged for |lead + feature - total| > 0.5 million: 400
Solo + collaborative streams reconcile with total streams; lead + feature streams generally do not. Totals used in rankings come from the total-streams column.

## Limitations

- The file is a 500-artist snapshot, not a random sample of all Spotify artists.
- Metrics are cumulative totals in millions of streams; they are not monthly rates.
- Statistical tests describe this catalog only.
- Multiple tests were run; p-values are descriptive diagnostics, not a pre-registered hypothesis set.
