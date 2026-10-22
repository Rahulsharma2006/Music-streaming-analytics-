# Data Cleaning Log

Generated: 2026-10-22 16:32:23 UTC

## Policy

- The original file `data/raw/Spotify Streaming Performance Dataset.csv` is never overwritten.
- The observed grain is one row per artist. Duplicate rows were checked and none were found, so none were removed.
- Missing values were checked and none were found.
- Categorical values were whitespace-normalized only; country and genre labels were not recoded.
- Lead + feature residuals are flagged rather than forced to equal total streams, because the mismatch is widespread and may reflect a source definition difference rather than a simple typo.
- Solo + collaborative streams were treated as the additive decomposition of total streams.

## Steps

- read_raw: Read the original CSV with trimmed header names. Raw file was not overwritten.
- normalize_names_and_types: Mapped original headers to snake_case, squished character fields, stored debut_year as integer.
- quality_flags: Flagged 400 artists whose lead+feature residual exceeds 0.5 million streams. No rows deleted.
