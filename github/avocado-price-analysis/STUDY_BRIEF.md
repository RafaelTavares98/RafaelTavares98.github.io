# Avocado price analysis, study brief

Original project: "Avocadocalypse" by Valentin Joseph. Portfolio page:
https://www.valentinjoseph.com/Portfolio/Avocado
Original repo (dead link, 404 as of 2026-08-24): github.com/valentinjoseph/avocadocalypse

This is a brief to rebuild the project, not a copy. The original repo is
unreachable, so nothing was cloned.

## Data sources
- Hass Avocado Board, weekly reports, 2015-2021.
- Census.gov population data for Los Angeles, 2015-2021.
- Cleaned dataset published on Kaggle by the original author:
  https://www.kaggle.com/valentinjoseph/avocado-sales-20152021-us-centric

## Tools used in the original
- Databricks cluster for processing.
- Data cleaning: region standardization, deduplication.
- Metrics tracked: date, average price, total volume, PLU-code-specific volume.

## Research questions
1. Does price influence sales volume?
2. Which regions consumed the most avocados, 2015-2021?
3. Is PLU4770 (extra-large Hass) the most consumed variety?
4. Does Los Angeles consumption mirror U.S. national trends?

## Findings in the original
- Small Hass avocados (PLU4046) became the top-selling variety after 2018.
- Los Angeles and New York are major consumption centers.
- Price alone does not predict sales. COVID-19 and product quality moved
  demand too.
- 2019 to 2020: price down 13%, sales up 20%.
- Per-capita consumption calculated for Los Angeles.

## To rebuild this yourself
1. Pull the Kaggle dataset above.
2. Load it in Postgres or Python, same as the SQL EDA project.
3. Answer the 4 questions above with your own queries.
4. Add a fifth angle the original does not have, so this is not a copy.
