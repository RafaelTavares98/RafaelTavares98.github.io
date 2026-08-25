/*
===============================================================================
Layers. The loader touches nothing, so every transformation lives here.
===============================================================================
  avocado_prices        landing      table, typed, nothing removed
  avocado_clean         conformed    view, safe to add up
  weekly_us             consumption  the national weekly series
  report_regions        consumption  one row per region (built in analysis.sql)
  data_quality_checks   test suite   one row per rule, with a verdict

This is the medallion shape without the medallion vocabulary. Bronze, silver
and gold carry machinery for scale, schema drift and incremental loads, and a
5 MB CSV has none of those problems.

Every statement is CREATE OR REPLACE, so this file is safe to run again.
===============================================================================
*/

-- ============================================================================
-- Conformed layer. One view, one job: make the rows safe to add up.
-- ============================================================================
CREATE OR REPLACE VIEW avocado_clean AS
SELECT
    sale_date,
    region,
    avocado_type,
    average_price,
    total_volume,
    plu4046,
    plu4225,
    plu4770,
    total_bags,
    sale_year,
    sale_year = 2018 AS is_partial_year
FROM avocado_prices
WHERE region NOT IN ('TotalUS', 'West', 'SouthCentral', 'Northeast', 'Southeast',
                     'GreatLakes', 'Midsouth', 'Plains', 'California');

-- ============================================================================
-- Consumption layer. The national weekly series, for the time windows.
-- ============================================================================
CREATE OR REPLACE VIEW weekly_us AS
SELECT
    sale_date,
    avocado_type,
    ROUND(AVG(average_price), 2) AS week_price,
    ROUND(SUM(total_volume)) AS week_volume
FROM avocado_prices
WHERE region = 'TotalUS'
GROUP BY sale_date, avocado_type;

-- ============================================================================
-- Consumption layer. One row per region, for whoever comes next.
-- ============================================================================
CREATE OR REPLACE VIEW report_regions AS
WITH base AS (
    SELECT
        region,
        sale_date,
        average_price,
        total_volume,
        plu4046 + plu4225 + plu4770 AS loose_units,
        total_bags
    FROM avocado_prices
    WHERE region <> 'TotalUS'
)
SELECT
    region,
    COUNT(DISTINCT sale_date) AS weeks_reported,
    ROUND(SUM(total_volume)) AS total_volume,
    ROUND(AVG(average_price), 2) AS avg_price,
    ROUND(MIN(average_price), 2) AS lowest_price,
    ROUND(MAX(average_price), 2) AS highest_price,
    ROUND(SUM(total_bags) / NULLIF(SUM(loose_units + total_bags), 0) * 100, 1) AS pct_bagged,
    ROUND(CORR(average_price, total_volume)::numeric, 2) AS price_volume_corr
FROM base
GROUP BY region;

-- ============================================================================
-- The test suite. One row per rule, and a verdict.
-- ============================================================================
CREATE OR REPLACE VIEW data_quality_checks AS
WITH checks AS (
    SELECT 1 AS rule_no, 'No null in any key field' AS rule,
        COUNT(*) FILTER (WHERE sale_date IS NULL OR region IS NULL
                            OR avocado_type IS NULL OR total_volume IS NULL) AS offenders
    FROM avocado_prices
    UNION ALL
    SELECT 2, 'One row per date, region and type',
        (SELECT COUNT(*) FROM (
            SELECT 1 FROM avocado_prices
            GROUP BY sale_date, region, avocado_type HAVING COUNT(*) > 1) d)
    UNION ALL
    SELECT 3, 'row_id is unique',
        (SELECT COUNT(*) - COUNT(DISTINCT row_id) FROM avocado_prices)
    UNION ALL
    SELECT 4, 'Volume equals the sum of its parts',
        COUNT(*) FILTER (WHERE ABS(total_volume
            - (plu4046 + plu4225 + plu4770 + total_bags)) > 1)
    FROM avocado_prices
    UNION ALL
    SELECT 5, 'sale_year agrees with sale_date',
        COUNT(*) FILTER (WHERE sale_year <> EXTRACT(YEAR FROM sale_date))
    FROM avocado_prices
    UNION ALL
    SELECT 6, 'No zero or negative price or volume',
        COUNT(*) FILTER (WHERE average_price <= 0 OR total_volume <= 0)
    FROM avocado_prices
    UNION ALL
    SELECT 7, 'Every series has all 169 weeks',
        (SELECT COUNT(*) FROM (
            SELECT 1 FROM avocado_prices
            GROUP BY region, avocado_type
            HAVING COUNT(DISTINCT sale_date) <> 169) s)
)
SELECT
    rule_no,
    rule,
    offenders,
    CASE WHEN offenders = 0 THEN 'pass' ELSE 'FAIL' END AS verdict
FROM checks;
