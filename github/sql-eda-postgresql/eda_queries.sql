/*
===============================================================================
SQL: Fundamental Exploratory Data Analysis - Postgres version
===============================================================================
Thesis: a small set of SQL commands answers most of what a business asks.
This script uses seventeen of them across the six steps of an exploratory
analysis, and every result it produces is on the project page.

    https://rafaeltavares98.github.io/sql-eda.html

Data:   Data With Baraa, "sql-data-analytics-project", MIT licensed.
        Written for SQL Server, rebuilt here for PostgreSQL 17.
Run:    psql -d datawarehouseanalytics -f 00_init.sql -f 01_load.sql -f eda_queries.sql

The full translation of the original 13 course scripts is kept in
reference/13-original-scripts.sql.
===============================================================================
*/



-- ============================================================================
-- 1. Read the structure
-- ============================================================================
-- Premise: every total downstream depends on what a single row represents.


-- What is in the fact table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'gold' AND table_name = 'fact_sales'
ORDER BY ordinal_position;

-- What does one row represent?
SELECT 'Rows in fact_sales' AS measure, COUNT(*) AS value FROM gold.fact_sales
UNION ALL SELECT 'Distinct order numbers', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL SELECT 'Distinct customers', COUNT(DISTINCT customer_key) FROM gold.fact_sales
UNION ALL SELECT 'Distinct products', COUNT(DISTINCT product_key) FROM gold.fact_sales;

-- Answer: a row is an order line, not an order. 60,398 lines across 27,659
-- orders, so any count of orders has to say DISTINCT.


-- ============================================================================
-- 2. Check the quality
-- ============================================================================
-- Premise: the fields are populated and the keys join. Worth testing.


-- Seven checks, one result
SELECT 'Missing order date' AS check_name, COUNT(*) AS failing_rows
FROM gold.fact_sales WHERE order_date IS NULL
UNION ALL SELECT 'Zero or negative sales', COUNT(*)
FROM gold.fact_sales WHERE COALESCE(sales_amount, 0) <= 0
UNION ALL SELECT 'Ship date before order date', COUNT(*)
FROM gold.fact_sales WHERE shipping_date < order_date
UNION ALL SELECT 'Product with no cost', COUNT(*)
FROM gold.dim_products WHERE COALESCE(cost, 0) = 0
UNION ALL SELECT 'Product with no category', COUNT(*)
FROM gold.dim_products WHERE category IS NULL
UNION ALL SELECT 'Sale with no matching product', COUNT(*)
FROM gold.fact_sales f LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
WHERE p.product_key IS NULL
UNION ALL SELECT 'Sale with no matching customer', COUNT(*)
FROM gold.fact_sales f LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;

-- Does the catalogue match what sells?
SELECT
    COALESCE(p.category, '(no category)') AS category,
    COUNT(DISTINCT p.product_key) AS products_listed,
    COUNT(DISTINCT f.product_key) AS products_sold
FROM gold.dim_products p
LEFT JOIN gold.fact_sales f ON f.product_key = p.product_key
GROUP BY COALESCE(p.category, '(no category)')
HAVING COUNT(DISTINCT p.product_key) > COUNT(DISTINCT f.product_key)
ORDER BY products_listed DESC;

-- Answer: half true. The keys hold. 19 order lines carry no date, 7 products
-- no category, 2 no cost, and 134 products have never sold.


-- ============================================================================
-- 3. Each field individually
-- ============================================================================
-- Premise: how large is the business, and is any field spread wide enough
-- to make its average useless?


-- The baseline
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL SELECT 'Total Quantity', SUM(quantity) FROM gold.fact_sales
UNION ALL SELECT 'Total Orders', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL SELECT 'Average Order Value', ROUND(SUM(sales_amount)::numeric / COUNT(DISTINCT order_number), 0) FROM gold.fact_sales
UNION ALL SELECT 'Total Products', COUNT(product_key) FROM gold.dim_products
UNION ALL SELECT 'Total Customers', COUNT(customer_key) FROM gold.dim_customers;

-- How wide is the price range?
SELECT
    COALESCE(category, '(no category)') AS category,
    COUNT(*) AS products,
    MIN(cost) AS cheapest,
    MAX(cost) AS most_expensive,
    ROUND(AVG(cost), 2) AS average_cost
FROM gold.dim_products
GROUP BY COALESCE(category, '(no category)')
ORDER BY average_cost DESC;

-- Answer: $1,061 an order. Cost runs from $1 to $2,171, so a catalogue-wide
-- average is meaningless. Every average from here is taken by category.


-- ============================================================================
-- 4. How fields relate
-- ============================================================================
-- Premise: a category with more products should bring in more money.


-- Catalogue size against revenue
SELECT
    COALESCE(p.category, '(no category)') AS category,
    COUNT(DISTINCT p.product_key) AS products,
    COALESCE(SUM(f.sales_amount), 0) AS total_revenue
FROM gold.dim_products p
LEFT JOIN gold.fact_sales f ON f.product_key = p.product_key
GROUP BY COALESCE(p.category, '(no category)')
ORDER BY total_revenue DESC;

-- How much of the whole is that?
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    ROUND(total_sales::numeric / SUM(total_sales) OVER () * 100, 2) AS pct_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- Answer: false. 97 bike products carry 96.46% of the revenue, and 191
-- products elsewhere split the rest. Catalogue size predicts nothing.


-- ============================================================================
-- 5. Changes over time
-- ============================================================================
-- Premise: the business is growing, and steadily enough to plan against.


-- The yearly trend
SELECT
    DATE_TRUNC('year', order_date)::date AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS active_customers
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('year', order_date)
ORDER BY order_year;

-- How much did each year move?
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM order_date)::int AS order_year,
        SUM(sales_amount) AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM order_date)
)
SELECT
    order_year,
    total_sales,
    LAG(total_sales) OVER (ORDER BY order_year) AS previous_year,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY order_year))::numeric
        / NULLIF(LAG(total_sales) OVER (ORDER BY order_year), 0) * 100, 1
    ) AS pct_change
FROM yearly
ORDER BY order_year;

-- Answer: growing, but not steadily. Down 17.4% in 2012, up 179.8% in 2013,
-- with 2010 and 2014 partial. One jump like that is an event, not a trend.


-- ============================================================================
-- 6. Split the population
-- ============================================================================
-- Premise: the revenue rests on a handful of large accounts.


-- Who are the largest customers?
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC
LIMIT 10;

-- What does the base look like?
WITH customer_spending AS (
    SELECT
        customer_key,
        SUM(sales_amount) AS total_spending,
        (EXTRACT(YEAR FROM MAX(order_date)) - EXTRACT(YEAR FROM MIN(order_date))) * 12
            + (EXTRACT(MONTH FROM MAX(order_date)) - EXTRACT(MONTH FROM MIN(order_date))) AS lifespan
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_key
)
SELECT
    CASE
        WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    COUNT(*) AS total_customers,
    ROUND(AVG(total_spending), 2) AS avg_spend
FROM customer_spending
GROUP BY customer_segment
ORDER BY total_customers DESC;

-- Answer: false. The top ten each spend near $13,000 with little gap. But 79%
-- of the base is under twelve months old, and this data cannot tell strong
-- acquisition from weak retention.


-- ============================================================================
-- Findings
-- ============================================================================
-- What does one row mean?          An order line. 60,398 lines, 27,659 orders.
-- Is the data clean?               Keys yes, fields no. 19 dateless rows.
-- How big, and how spread?         $1,061 an order. Cost from $1 to $2,171.
-- Does catalogue size drive        No. 97 bike products carry 96.46%.
--   revenue?
-- Is growth steady?                No. One 179.8% year between a fall and a stub.
-- Who carries the revenue?         Nobody. 79% of the base is under a year old.
--
-- Four of those close a door. Two open one: 134 products that never sold, and
-- a customer base too young to read. Both need the follow-up project.
-- ============================================================================
