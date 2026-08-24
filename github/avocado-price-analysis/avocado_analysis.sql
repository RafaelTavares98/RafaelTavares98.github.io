-- Q1: Does price influence sales volume?
SELECT
    CORR(average_price, total_volume) AS price_volume_correlation
FROM avocado_prices
WHERE region <> 'TotalUS';

-- Q2: Which regions consumed the most avocados?
SELECT
    region,
    SUM(total_volume) AS total_volume_2015_2018
FROM avocado_prices
WHERE region <> 'TotalUS'
GROUP BY region
ORDER BY total_volume_2015_2018 DESC
LIMIT 10;

-- Q3: Which PLU variety is the most consumed?
SELECT
    'PLU4046 (small Hass)' AS variety, SUM(plu4046) AS total_volume FROM avocado_prices
UNION ALL
SELECT 'PLU4225 (large Hass)', SUM(plu4225) FROM avocado_prices
UNION ALL
SELECT 'PLU4770 (extra-large Hass)', SUM(plu4770) FROM avocado_prices
ORDER BY total_volume DESC;

-- Q4: Does Los Angeles consumption mirror U.S. national trends?
SELECT
    sale_year,
    ROUND(SUM(CASE WHEN region = 'LosAngeles' THEN total_volume END)) AS los_angeles_volume,
    ROUND(SUM(CASE WHEN region = 'TotalUS' THEN total_volume END)) AS total_us_volume
FROM avocado_prices
WHERE region IN ('LosAngeles', 'TotalUS')
GROUP BY sale_year
ORDER BY sale_year;
