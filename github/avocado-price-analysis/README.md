# SQL: Advanced Analysis with CRISP-DM

Window functions carry the SQL. CRISP-DM carries the order. Three years of
weekly U.S. avocado prices as the case, in PostgreSQL 17.

This is the second of two SQL projects. The
[first one](https://rafaeltavares98.github.io/sql-eda.html) argues that
seventeen commands answer most of what a business asks. They run out at the
point a question needs one row compared against another, which is where this
one starts.

**Project page:** https://rafaeltavares98.github.io/avocado-price-analysis.html

## The finding

The published headline for this data set is a price-volume correlation of
**-0.34**, and it is wrong in a way that matters.

| Held constant | Correlation | Groups |
| --- | --- | --- |
| Everything pooled | -0.34 | 1 |
| Region | **-0.72** | 53 |
| Region and type | -0.48 | 106 |

Pooling 53 markets and two product lines into one figure halves the
relationship. Inside a single market, where a buyer actually works, price and
volume move strongly against each other. A correlation reported without saying
what was held constant is unusable.

## The method

| Phase | What it answers | Where it lives |
| --- | --- | --- |
| 1. Business understanding | What decision is this for, and what counts as an answer? | `analysis.sql`, no query |
| 2. Data understanding | What is wrong with the table? | `data_quality_checks` |
| 3. Data preparation | What gets dropped, and what does it cost? | `02_model.sql` |
| 4. Modelling | The windows that answer the question | `analysis.sql` |
| 5. Evaluation | Does the answer survive being split apart? | `analysis.sql` |
| 6. Deployment | Who queries this after I stop? | `report_regions` |

CRISP-DM is a cycle. Each loop returns to the phase before it, and every turn
removes noise. In this project the loop caught a wrong answer before it shipped.

## The SLI and the SLO

Phase one names what gets measured and what counts as good enough, before the
first query runs.

* **SLI.** Price against volume, correlated inside one market and one year.
* **SLO.** -0.50 or stronger in 80% of markets, every year.

Phase five returns the verdict:

| Year | Markets | Meeting the SLO | Verdict |
| --- | --- | --- | --- |
| 2015 | 53 | 100.0% | pass |
| 2016 | 53 | 100.0% | pass |
| 2017 | 53 | 86.8% | pass |
| 2018 | 53 | 94.3% | pass |

2017 is the narrow year, which fits the shock, when supply set the price.

## The skills

SQL · PostgreSQL 17 · window functions · layered ELT · data cleaning · CRISP-DM

`AVG() OVER (ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)` · `LAG(col, 52)` ·
`RANK() OVER (PARTITION BY ...)` · `SUM() OVER ()` · running totals · CTEs ·
`CASE WHEN` bands · `CORR` · `NULLIF` · `FILTER` · `CREATE OR REPLACE VIEW`


## The layers

The loader touches nothing, so every transformation lives in the database.
That makes this ELT rather than ETL.

| Layer | Object | Job |
| --- | --- | --- |
| Landing | `avocado_prices` | A table. Typed, nothing removed. |
| Conformed | `avocado_clean` | A view. Drops the nine overlapping regions and `row_id`, flags the partial year. |
| Consumption | `weekly_us`, `report_regions` | A view per question. |
| Tests | `data_quality_checks` | One row per rule, with a verdict. |

This is the medallion shape with the medallion vocabulary left off. Bronze,
silver and gold come with machinery for scale, schema drift and incremental
loads, and a 5 MB CSV has none of those problems. Views rather than tables,
because the transformation is cheap and never goes stale. That choice inverts
when recomputing starts to hurt, or when somebody needs to know what the layer
said last week.

## What the tests find

Four rules pass. Three fail, and the failures are the point.

| Rule | Result |
| --- | --- |
| No null in any key field | pass |
| One row per date, region and type | pass |
| `row_id` is unique | **FAIL**, 53 distinct values across 18,249 rows |
| Volume equals the sum of its parts | **FAIL**, 181 rows, worst gap 7.9% |
| `sale_year` agrees with `sale_date` | pass |
| No zero or negative price or volume | pass |
| Every series has all 169 weeks | **FAIL**, one series holds 166 |

`row_id` is the week counter from the source export, and it restarts inside
every region, type and year. Joining on it destroys the data quietly.

The short series is organic in WestTexNewMexico, which skips three weeks. That
one matters because `LAG(col, 52)` assumes an unbroken weekly grid: a gap makes
the offset look at the wrong date without raising anything.

## The data

Hass Avocado Board weekly reports, through the public
[Avocado Prices](https://www.kaggle.com/datasets/neuromusic/avocado-prices)
data set on Kaggle. 18,249 rows, 2015-01-04 to 2018-03-25, 54 regions, and two
product types. The CSV is in `data/`.

**One trap worth knowing.** The `region` column mixes eight multi-state
aggregates, such as `West` and `SouthCentral`, with the metros they already
contain, and with `TotalUS`. Summing every region overstates the country by
3.79 billion units, or 65%. Every query here filters to metros or to
`TotalUS`, never both.

## How to run it

PostgreSQL 17 and `psql` are the only requirements. Run from this folder:

```bash
createdb avocado_analysis
psql -d avocado_analysis -f 00_init.sql -f 01_load.sql -f 02_model.sql -f analysis.sql
```

Every statement in `02_model.sql` is `CREATE OR REPLACE`, so the whole thing is
safe to run again.

## The files

| File | What it holds |
| --- | --- |
| `00_init.sql` | The `avocado_prices` table |
| `01_load.sql` | Loads `data/avocado.csv` with a client-side `\copy` |
| `02_model.sql` | The layers and the test suite |
| `analysis.sql` | The queries, each with its premise and its answer |
| `REPORT.md` | The earlier pass over this data, kept as the record |
| `STUDY_BRIEF.md` | The original project this rebuild started from |

## What it found

| Question | Answer |
| --- | --- |
| Can these rows be added up? | No. Aggregates overlap metros and overstate the country by 65%. |
| Does price move volume? | Inside a market, strongly: -0.72. Pooled, -0.34 and misleading. |
| Is the weekly series noisy? | No. The widest gap from its own 4-week average is 21 cents. |
| Was 2017 unusual? | Yes. September ran 33% to 51% above the year before. |
| Is the metro table moving? | Barely. Houston took two places, everything else held. |
| Does that hold up? | Yes. Every year, -0.66 to -0.88, across all 53 markets. |
| Do both product lines react alike? | No. Conventional is four to one on price, organic under two and a half. |

The buyer from phase one gets a different answer than the published one. Price
is a real lever in a single market, worth roughly twice what the headline
figure implies.
