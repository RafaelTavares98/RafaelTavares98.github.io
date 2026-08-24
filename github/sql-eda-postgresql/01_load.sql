-- Server-side COPY. The PostgreSQL service account must read this folder.
COPY gold.dim_customers FROM 'C:/Users/tavar/Downloads/sqlproj/sql-data-analytics-project/datasets/flat-files/dim_customers.csv' WITH (FORMAT csv, HEADER true);
COPY gold.dim_products  FROM 'C:/Users/tavar/Downloads/sqlproj/sql-data-analytics-project/datasets/flat-files/dim_products.csv'  WITH (FORMAT csv, HEADER true);
COPY gold.fact_sales    FROM 'C:/Users/tavar/Downloads/sqlproj/sql-data-analytics-project/datasets/flat-files/fact_sales.csv'    WITH (FORMAT csv, HEADER true);
