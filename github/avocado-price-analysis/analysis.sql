/*
===============================================================================
SQL: Advanced Analysis with CRISP-DM - PostgreSQL 17
===============================================================================
Window functions carry the SQL. CRISP-DM carries the order. Three years of
weekly U.S. avocado prices, 2015-01-04 to 2018-03-25, as the case.

    https://rafaeltavares98.github.io/avocado-price-analysis.html

The six phases, and where each one lives:

    1. Business understanding   below, no query
    2. Data understanding       below, plus data_quality_checks in 02_model.sql
    3. Data preparation         the layers in 02_model.sql, tested below
    4. Modelling                below
    5. Evaluation               below
    6. Deployment               report_regions in 02_model.sql, queried below

Data:   Hass Avocado Board weekly reports, via the public Kaggle
        "Avocado Prices" data set. 18,249 rows, 54 regions, two types.
Run:    createdb avocado_analysis
        psql -d avocado_analysis -f 00_init.sql -f 01_load.sql
                                 -f 02_model.sql -f analysis.sql

Every result this script prints is on the project page.
===============================================================================
*/


-- ============================================================================
-- 1. Business understanding
-- ============================================================================
-- A produce buyer holds one week of stock and sets one price. Two decisions
-- follow: how much to buy, and what to charge. Both need the same answer.
--
--     Does price move volume, and by how much in the market I buy for?
--
-- The published answer for this data set is a correlation of -0.34, weak
-- enough that a buyer would conclude price is not a lever worth pulling.
-- That number is the thing to test.
--
-- Two lines, written before any query runs, so no result sets its own bar.
--
--     SLI: price against volume, correlated inside one market and one year.
--     SLO: -0.50 or stronger in 80% of markets, every year.
--
-- Phase 5 returns the verdict, and the verdict decides the recommendation.



-- ============================================================================
-- 2. Data understanding
-- ============================================================================
-- Premise: the data set arrives claiming to be clean. Seven rules test it.

-- Run the suite (defined in 02_model.sql)
SELECT rule_no, rule, offenders, verdict
FROM data_quality_checks
ORDER BY rule_no;

-- The shape underneath
SELECT
    COUNT(*) AS weekly_rows,
    COUNT(DISTINCT region) AS regions,
    COUNT(DISTINCT avocado_type) AS types,
    MIN(sale_date) AS first_week,
    MAX(sale_date) AS last_week
FROM avocado_prices;

-- The trap no rule catches: aggregates overlap the metros they contain
SELECT
    'Sum of every region except TotalUS' AS measure,
    ROUND(SUM(CASE WHEN region <> 'TotalUS' THEN total_volume END)) AS units
FROM avocado_prices
UNION ALL SELECT 'Reported TotalUS',
    ROUND(SUM(CASE WHEN region = 'TotalUS' THEN total_volume END))
FROM avocado_prices
UNION ALL SELECT 'Overstatement',
    ROUND(SUM(CASE WHEN region <> 'TotalUS' THEN total_volume END)
        - SUM(CASE WHEN region = 'TotalUS' THEN total_volume END))
FROM avocado_prices;

-- Answer: four rules pass, three fail. row_id is a week counter, not an id.
-- 181 rows report a total that is not the sum of its parts. One series is short.
-- And summing every region overstates the country by 65%.


-- ============================================================================
-- 3. Data preparation
-- ============================================================================
-- Premise: LAG(col, 52) assumes an unbroken weekly grid. Test it before use.

-- What each layer holds
SELECT 'avocado_prices (landing)' AS layer, COUNT(*) AS rows,
       COUNT(DISTINCT region) AS regions
FROM avocado_prices
UNION ALL
SELECT 'avocado_clean (conformed)', COUNT(*), COUNT(DISTINCT region)
FROM avocado_clean
UNION ALL
SELECT 'weekly_us (consumption)', COUNT(*), 1
FROM weekly_us
UNION ALL
SELECT 'report_regions (consumption)', COUNT(*), COUNT(*)
FROM report_regions;

-- Find any week that is not seven days after the last
WITH steps AS (
    SELECT
        region,
        avocado_type,
        sale_date,
        sale_date - LAG(sale_date) OVER (
            PARTITION BY region, avocado_type ORDER BY sale_date) AS days_since_previous
    FROM avocado_prices
)
SELECT region, avocado_type, sale_date, days_since_previous
FROM steps
WHERE days_since_previous <> 7
ORDER BY sale_date;

-- Answer: organic in WestTexNewMexico jumps 14 days once and 21 once, so it
-- holds 166 weeks of 169. The time windows below run on TotalUS, which is whole.


-- ============================================================================
-- 4. Modelling
-- ============================================================================
-- Premise: one correlation across the table settles it.

-- The same question at three levels
WITH by_region AS (
    SELECT CORR(average_price, total_volume)::numeric AS c
    FROM avocado_prices WHERE region <> 'TotalUS' GROUP BY region
),
by_region_and_type AS (
    SELECT CORR(average_price, total_volume)::numeric AS c
    FROM avocado_prices WHERE region <> 'TotalUS' GROUP BY region, avocado_type
)
SELECT 'Everything pooled' AS held_constant,
       ROUND(CORR(average_price, total_volume)::numeric, 2) AS price_volume_corr,
       1 AS groups
FROM avocado_prices WHERE region <> 'TotalUS'
UNION ALL
SELECT 'Region', ROUND(AVG(c), 2), COUNT(*) FROM by_region
UNION ALL
SELECT 'Region and type', ROUND(AVG(c), 2), COUNT(*) FROM by_region_and_type;

-- Answer: it does not. Pooled it is -0.34. Inside a single market it averages
-- -0.72. What was held constant is the finding, not the number.


-- ============================================================================
-- 4a. Trend against noise
-- ============================================================================
-- Premise: a weekly price series is noisy enough to need smoothing.

-- Four-week moving average, and the weeks that broke it
WITH weekly AS (
    SELECT
        sale_date,
        ROUND(AVG(average_price), 2) AS week_price
    FROM avocado_prices
    WHERE region = 'TotalUS' AND avocado_type = 'conventional'
    GROUP BY sale_date
)
SELECT
    sale_date,
    week_price,
    ROUND(AVG(week_price) OVER (
        ORDER BY sale_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS moving_avg_4w,
    ROUND(week_price - AVG(week_price) OVER (
        ORDER BY sale_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS gap
FROM weekly
ORDER BY ABS(week_price - AVG(week_price) OVER (
    ORDER BY sale_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)) DESC
LIMIT 6;

-- Answer: barely. The widest gap from its own four-week average is 21 cents,
-- in December 2016.


-- ============================================================================
-- 4b. This year against last year
-- ============================================================================
-- Premise: the series is stable year on year.

-- Every September, against the September before
WITH weekly AS (
    SELECT
        sale_date,
        ROUND(AVG(average_price), 2) AS week_price
    FROM avocado_prices
    WHERE region = 'TotalUS' AND avocado_type = 'conventional'
    GROUP BY sale_date
),
against_last_year AS (
    SELECT
        sale_date,
        week_price,
        LAG(week_price, 52) OVER (ORDER BY sale_date) AS same_week_last_year
    FROM weekly
)
SELECT
    sale_date,
    week_price,
    same_week_last_year,
    ROUND((week_price - same_week_last_year)
        / NULLIF(same_week_last_year, 0) * 100, 1) AS pct_change
FROM against_last_year
WHERE same_week_last_year IS NOT NULL
  AND EXTRACT(MONTH FROM sale_date) = 9
ORDER BY sale_date;

-- Answer: false. September 2017 ran 33% to 51% above September 2016.
--
-- Note the WHERE sits in the outer query. Filtering to September before the
-- window runs makes LAG look back 52 September rows, which do not exist.


-- ============================================================================
-- 4c. This market against the others
-- ============================================================================
-- Premise: a ranking by size shows who is winning.

-- The 2017 table, and the movement behind it
WITH metro_year AS (
    SELECT
        region,
        sale_year,
        SUM(total_volume) AS volume
    FROM avocado_prices
    WHERE region IN ('LosAngeles', 'NewYork', 'Houston', 'DallasFtWorth',
                     'PhoenixTucson', 'Chicago', 'Denver', 'Seattle')
      AND sale_year < 2018
    GROUP BY region, sale_year
),
ranked AS (
    SELECT
        region,
        sale_year,
        volume,
        RANK() OVER (PARTITION BY sale_year ORDER BY volume DESC) AS rank_in_year
    FROM metro_year
),
with_move AS (
    SELECT
        region,
        sale_year,
        volume,
        rank_in_year,
        LAG(rank_in_year) OVER (PARTITION BY region ORDER BY sale_year) - rank_in_year
            AS places_gained,
        ROUND((volume - LAG(volume) OVER (PARTITION BY region ORDER BY sale_year))
            / NULLIF(LAG(volume) OVER (PARTITION BY region ORDER BY sale_year), 0) * 100, 1)
            AS volume_change_pct
    FROM ranked
)
SELECT region, rank_in_year, ROUND(volume) AS volume, places_gained, volume_change_pct
FROM with_move
WHERE sale_year = 2017
ORDER BY rank_in_year;

-- How concentrated is that?
WITH metro_volume AS (
    SELECT
        region,
        SUM(total_volume) AS volume
    FROM avocado_prices
    WHERE region IN ('LosAngeles', 'NewYork', 'Houston', 'DallasFtWorth',
                     'PhoenixTucson', 'Chicago', 'Denver', 'Seattle')
    GROUP BY region
)
SELECT
    region,
    ROUND(volume) AS volume,
    ROUND(volume / SUM(volume) OVER () * 100, 1) AS pct_of_these_metros,
    ROUND(SUM(volume) OVER (ORDER BY volume DESC) / SUM(volume) OVER () * 100, 1) AS running_pct
FROM metro_volume
ORDER BY volume DESC;

-- Answer: it does not. Only Houston moved, taking two places on 17.7% growth
-- while Los Angeles shrank 2.9%. Los Angeles alone is 29.2% of these metros.


-- ============================================================================
-- 4d. Where the price bites
-- ============================================================================
-- Premise: cheap weeks sell more, and both product lines react alike.

-- Volume by price band, conventional against organic
SELECT
    avocado_type,
    CASE
        WHEN average_price < 1.00 THEN 'Under $1.00'
        WHEN average_price < 1.50 THEN '$1.00 to $1.49'
        WHEN average_price < 2.00 THEN '$1.50 to $1.99'
        ELSE '$2.00 and above'
    END AS price_band,
    COUNT(*) AS weeks,
    ROUND(AVG(total_volume)) AS avg_weekly_volume
FROM avocado_prices
WHERE region <> 'TotalUS'
GROUP BY avocado_type, price_band
ORDER BY avocado_type, price_band;

-- Answer: half true. Conventional runs close to four to one between the cheapest
-- and dearest bands. Organic is under two and a half to one.


-- ============================================================================
-- 5. Evaluation
-- ============================================================================
-- Premise: a finding that only exists in the aggregate is waiting to be withdrawn.

-- The same correlation, split by year
WITH by_region_year AS (
    SELECT
        sale_year,
        region,
        CORR(average_price, total_volume)::numeric AS c
    FROM avocado_prices
    WHERE region <> 'TotalUS'
    GROUP BY sale_year, region
)
SELECT
    sale_year,
    COUNT(*) AS markets,
    ROUND(AVG(c), 2) AS avg_corr,
    ROUND(MIN(c), 2) AS strongest,
    ROUND(MAX(c), 2) AS weakest
FROM by_region_year
GROUP BY sale_year
ORDER BY sale_year;

-- Answer: it holds. Every year averages -0.66 to -0.88 across all 53 markets.

-- The SLI by year, and the SLO verdict
WITH sli AS (
    SELECT
        sale_year,
        region,
        CORR(average_price, total_volume)::numeric AS price_volume_sli
    FROM avocado_prices
    WHERE region <> 'TotalUS'
    GROUP BY sale_year, region
)
SELECT
    sale_year,
    COUNT(*) AS markets,
    COUNT(*) FILTER (WHERE price_volume_sli <= -0.50) AS markets_meeting,
    ROUND(100.0 * COUNT(*) FILTER (WHERE price_volume_sli <= -0.50)
        / COUNT(*), 1) AS pct_meeting,
    CASE WHEN 100.0 * COUNT(*) FILTER (WHERE price_volume_sli <= -0.50)
        / COUNT(*) >= 80 THEN 'pass' ELSE 'FAIL' END AS slo_verdict
FROM sli
GROUP BY sale_year
ORDER BY sale_year;

-- Answer: the SLO passes in all four years. 100%, 100%, 86.8% and 94.3%.
-- 2017 is the narrow one, which fits the shock year, when supply set the price.


-- ============================================================================
-- 6. Deployment
-- ============================================================================
-- Premise: an analysis nobody can rerun is a screenshot.

-- One row per region, ready to query
-- report_regions is created in 02_model.sql, with the other views.

SELECT region, weeks_reported, total_volume, avg_price, pct_bagged, price_volume_corr
FROM report_regions
ORDER BY total_volume DESC
LIMIT 8;

-- Answer: every region reports all 169 weeks, and the per-region
-- correlations run from -0.69 to -0.84, which is step 2 at row level.


-- ============================================================================
-- Findings
-- ============================================================================
-- Can these rows be added up?     No. Aggregates overlap metros, 65% over.
-- Does price move volume?         In a market, -0.72. Pooled, -0.34, misleading.
-- Does that hold up?              Every year, -0.66 to -0.88, all 53 markets.
-- Is the weekly series noisy?     No. Widest gap from its 4-week average: 21c.
-- Was 2017 unusual?               Yes. September ran 33% to 51% over.
-- Is the metro table moving?      Barely. Houston took two places.
-- Do both product lines match?    No. Conventional 4:1, organic under 2.5:1.
--
-- The buyer from phase 1 gets a different answer than the published one. Price
-- is a real lever in a single market, worth roughly twice what the headline
-- figure implies, and blunter for organic than for conventional.
--
-- Neither correction needed a tool beyond PostgreSQL. Both came from asking
-- what the number was being compared against, which is the question CRISP-DM
-- forces before the answer ships rather than after.
-- ============================================================================
