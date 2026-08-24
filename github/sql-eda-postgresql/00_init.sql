-- Run this after you create the database "datawarehouseanalytics".
CREATE SCHEMA IF NOT EXISTS gold;

DROP TABLE IF EXISTS gold.fact_sales, gold.dim_customers, gold.dim_products;

CREATE TABLE gold.dim_customers (
    customer_key    INT PRIMARY KEY, -- surrogate key, unique row identifier
    customer_id     INT,             -- source system customer identifier
    customer_number VARCHAR(50),     -- business-facing customer code (AW#####)
    first_name      VARCHAR(50),     -- customer given name
    last_name       VARCHAR(50),     -- customer family name
    country         VARCHAR(50),     -- customer country of residence
    marital_status  VARCHAR(50),     -- customer marital status (Married/Single)
    gender          VARCHAR(50),     -- customer gender (Male/Female)
    birthdate       DATE,            -- customer date of birth
    create_date     DATE             -- date the customer record was created
);

CREATE TABLE gold.dim_products (
    product_key    INT PRIMARY KEY, -- surrogate key, unique row identifier
    product_id     INT,             -- source system product identifier
    product_number VARCHAR(50),     -- business-facing product code
    product_name   VARCHAR(50),     -- full descriptive product name
    category_id    VARCHAR(50),     -- code linking product to its category
    category       VARCHAR(50),     -- top-level product grouping
    subcategory    VARCHAR(50),     -- second-level product grouping
    maintenance    VARCHAR(50),     -- whether the product requires maintenance
    cost           INT,             -- product cost to the business
    product_line   VARCHAR(50),     -- product line the item belongs to
    start_date     DATE             -- date the product became available
);

CREATE TABLE gold.fact_sales (
    order_number  VARCHAR(50), -- unique identifier of the sales order
    product_key   INT,         -- references gold.dim_products.product_key
    customer_key  INT,         -- references gold.dim_customers.customer_key
    order_date    DATE,        -- date the order was placed
    shipping_date DATE,        -- date the order was shipped
    due_date      DATE,        -- date the order was due for delivery
    sales_amount  INT,         -- total revenue for this order line
    quantity      SMALLINT,    -- number of units sold in this order line
    price         INT          -- unit price of the product in this order line
);
