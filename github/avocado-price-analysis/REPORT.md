# Avocado price analysis, rebuilt

> **Superseded.** This was the first pass over the data, four queries answering
> the original project's questions. The conclusion in Q1, that the price to
> volume relationship is moderate, does not survive the current analysis: the
> -0.34 figure pools 53 markets and two product lines, and inside a single
> market the correlation averages -0.72. The file is kept as the record of what
> the first pass said. See `README.md` for the current work.

A rebuild of Valentin Joseph's "Avocadocalypse" project. His original repo
returned 404 on 2026-08-24, so this uses a different real dataset: the
public "Avocado Prices" Kaggle dataset (Hass Avocado Board, weekly,
2015-01-04 to 2018-03-25), pulled from a public mirror on GitHub. It is not
the same date range as the original (2015-2021), and results below are
computed from this data, not copied from his findings.

Database: `avocado_analysis`, table `avocado_prices`, 18,249 rows, loaded
with `avocado_analysis.sql` in this folder.

## Q1: Does price influence sales volume?
`CORR(average_price, total_volume) = -0.34`. A moderate negative
correlation. Higher price associates with lower volume, but the
relationship is not strong, other factors move volume too.

## Q2: Which regions consumed the most avocados?
Top 3 by total volume, 2015-2018: West, California, SouthCentral. Note the
dataset mixes multi-state regions (West, SouthCentral) with single metros
(LosAngeles, NewYork), so this is not an apples-to-apples city ranking.

## Q3: Which PLU variety is the most consumed?
PLU4225 (large Hass) narrowly leads PLU4046 (small Hass): 5.39B vs 5.35B
units. PLU4770 (extra-large) trails far behind at 0.42B. This data ends in
March 2018 and does not confirm Valentin's claim that small Hass overtook
large Hass after 2018.

## Q4: Does Los Angeles consumption mirror U.S. national trends?
LosAngeles volume tracks close to a constant ~8-9% of TotalUS volume in
2015, 2016, and 2017. 2018 figures are a partial year (through March only),
so that row is not comparable to the full years.

## Files in this folder
- `avocado.csv` — the dataset used.
- `avocado_analysis.sql` — the 4 queries above.
- `STUDY_BRIEF.md` — the original project's stated methodology and findings.
- `REPORT.md` — this file.
