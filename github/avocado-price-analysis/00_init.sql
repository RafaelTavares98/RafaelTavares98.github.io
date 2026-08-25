-- Run this after you create the database "avocado_analysis".
DROP TABLE IF EXISTS avocado_prices;

CREATE TABLE avocado_prices (
    row_id        INTEGER,       -- row number from the source export
    sale_date     DATE,          -- week ending date
    average_price NUMERIC,       -- average price of a single avocado that week
    total_volume  NUMERIC,       -- total units sold
    plu4046       NUMERIC,       -- small Hass
    plu4225       NUMERIC,       -- large Hass
    plu4770       NUMERIC,       -- extra-large Hass
    total_bags    NUMERIC,       -- units sold in bags
    small_bags    NUMERIC,
    large_bags    NUMERIC,
    xlarge_bags   NUMERIC,
    avocado_type  VARCHAR(20),   -- conventional or organic
    sale_year     INTEGER,
    region        VARCHAR(50)    -- metro, multi-state aggregate, or TotalUS
);
