-- Client-side \copy, so it needs no permission on the PostgreSQL service
-- account and the paths stay relative to this folder.
-- Run it from this folder: psql -d datawarehouseanalytics -f 01_load.sql

\copy gold.dim_customers FROM 'data/dim_customers.csv' WITH (FORMAT csv, HEADER true);
\copy gold.dim_products  FROM 'data/dim_products.csv'  WITH (FORMAT csv, HEADER true);
\copy gold.fact_sales    FROM 'data/fact_sales.csv'    WITH (FORMAT csv, HEADER true);
