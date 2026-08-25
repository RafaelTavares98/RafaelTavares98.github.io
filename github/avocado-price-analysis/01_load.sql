-- Client-side \copy, so it needs no permission on the PostgreSQL service
-- account and the path stays relative to this folder.
-- Run it from this folder: psql -d avocado_analysis -f 01_load.sql

\copy avocado_prices FROM 'data/avocado.csv' WITH (FORMAT csv, HEADER true);
