# SQL: Fundamental Exploratory Data Analysis

A small set of SQL commands answers most of what a business asks. This project
puts seventeen of them through the six steps of an exploratory analysis on a
sales data warehouse, and every query here produced a result on the project
page.

**Project page:** https://rafaeltavares98.github.io/sql-eda.html

## The commands

`SELECT / FROM` · `WHERE` · `DISTINCT` · `JOIN` · `GROUP BY` · `HAVING` ·
`SUM, COUNT, AVG` · `MIN, MAX` · `ORDER BY` · `LIMIT` · `UNION ALL` ·
`CASE WHEN` · `CTE (WITH)` · window functions · subqueries · date functions ·
`COALESCE, NULLIF`

## The data

The warehouse is the teaching data set from
[Data With Baraa](https://github.com/DataWithBaraa/sql-data-analytics-project),
MIT licensed. It was written for SQL Server. The schema and every query here
were rebuilt for PostgreSQL 17.

A bicycle retailer in a star schema: 60,398 order lines, 18,484 customers, and
295 products, from 2010 to 2014. The three source CSV files are in `data/`.

## How to run it

PostgreSQL 17 and `psql` are the only requirements. Run from this folder:

```bash
createdb datawarehouseanalytics
psql -d datawarehouseanalytics -f 00_init.sql -f 01_load.sql -f eda_queries.sql
```

`01_load.sql` uses the client-side `\copy`, so it needs no file permission on
the PostgreSQL service account.

## The files

| File | What it holds |
| --- | --- |
| `00_init.sql` | The `gold` schema and the three tables |
| `01_load.sql` | Loads the CSV files in `data/` |
| `eda_queries.sql` | The twelve queries, in the order of the six EDA steps |
| `reference/13-original-scripts.sql` | The full translation of the original 13 course scripts, kept as the record of the SQL Server to PostgreSQL work |

## What it found

| Question | Answer |
| --- | --- |
| What does one row mean? | An order line. 60,398 lines, 27,659 orders. |
| Is the data clean? | Keys yes, fields no. 19 dateless rows, 9 broken products. |
| How big, and how spread? | $1,061 an order. Cost from $1 to $2,171. |
| Does catalogue size drive revenue? | No. 97 bike products carry 96.46%. |
| Is growth steady? | No. One 179.8% year between a fall and a stub. |
| Who carries the revenue? | Nobody. 79% of the base is under a year old. |

Four of those close a door. Two open one: 134 products that have never sold,
and a customer base too young to read. Both need cohort logic and heavier
window work, which is the follow-up project.
