-- eda and summary statistics

-- users
SELECT * FROM users;

-- users summary
WITH base_users AS (
    SELECT 
        user_id,
        city,
        is_driver,
        CAST((julianday((SELECT MAX(date_joined) FROM users)) - julianday(date_joined)) / 365.25 AS INTEGER) AS user_since_years
    FROM users
),
quartiles AS (
    SELECT 
        user_id,
        is_driver,
        user_since_years,
        NTILE(4) OVER (ORDER BY user_id) AS q_id,
        NTILE(4) OVER (ORDER BY is_driver) AS q_driver,
        NTILE(4) OVER (ORDER BY user_since_years) AS q_since
    FROM base_users
)
SELECT 
    'user_id' AS column_name,
    COUNT(user_id) AS count,
    COUNT(DISTINCT user_id) AS distinct_count,
    ROUND(AVG(user_id), 2) AS mean,
    ROUND(MIN(user_id), 2) AS min,
    ROUND(MAX(CASE WHEN q_id = 1 THEN user_id END), 2) AS "25%",
    ROUND(MAX(CASE WHEN q_id = 2 THEN user_id END), 2) AS "50%",
    ROUND(MAX(CASE WHEN q_id = 3 THEN user_id END), 2) AS "75%",
    ROUND(MAX(user_id), 2) AS max
FROM quartiles

UNION ALL

SELECT 
    'user_since_years' AS column_name,
    COUNT(user_since_years), 
    COUNT(DISTINCT user_since_years),
    ROUND(AVG(user_since_years), 2), 
    ROUND(MIN(user_since_years), 2),
    ROUND(MAX(CASE WHEN q_since = 1 THEN user_since_years END), 2),
    ROUND(MAX(CASE WHEN q_since = 2 THEN user_since_years END), 2),
    ROUND(MAX(CASE WHEN q_since = 3 THEN user_since_years END), 2),
    ROUND(MAX(user_since_years), 2)
FROM quartiles

UNION ALL

SELECT 
    'is_driver' AS column_name,
    COUNT(is_driver), 
    COUNT(DISTINCT is_driver),
    ROUND(AVG(is_driver), 2), 
    ROUND(MIN(is_driver), 2),
    ROUND(MAX(CASE WHEN q_driver = 1 THEN is_driver END), 2),
    ROUND(MAX(CASE WHEN q_driver = 2 THEN is_driver END), 2),
    ROUND(MAX(CASE WHEN q_driver = 3 THEN is_driver END), 2),
    ROUND(MAX(is_driver), 2)
FROM quartiles

UNION ALL

SELECT 
    'city' AS column_name,
    COUNT(city), 
    COUNT(DISTINCT city),
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL
FROM base_users;

-- users overview:
-- 2000 unique users
-- ~6 years of data
-- most users arent drivers
-- user table covers 4 cities

-- drivers
SELECT * FROM drivers;

-- summary
WITH base_drivers AS (
    SELECT 
        driver_id,
        vehicle_year,
        rating,
        is_active,
        CAST((julianday((SELECT MAX(join_date) FROM drivers)) - julianday(join_date)) / 365.25 AS INTEGER) AS years_driving
    FROM drivers
),
quartiles AS (
    SELECT 
        driver_id,
        vehicle_year,
        rating,
        is_active,
        years_driving,
        NTILE(4) OVER (ORDER BY driver_id) AS q_id,
        NTILE(4) OVER (ORDER BY vehicle_year) AS q_year,
        NTILE(4) OVER (ORDER BY rating) AS q_rating,
        NTILE(4) OVER (ORDER BY is_active) AS q_active,
        NTILE(4) OVER (ORDER BY years_driving) AS q_years
    FROM base_drivers
)
SELECT 
    'driver_id' AS column_name,
    COUNT(driver_id) AS count,
    COUNT(DISTINCT driver_id) AS distinct_count,
    ROUND(AVG(driver_id), 2) AS mean,
    ROUND(MIN(driver_id), 2) AS min,
    ROUND(MAX(CASE WHEN q_id = 1 THEN driver_id END), 2) AS "25%",
    ROUND(MAX(CASE WHEN q_id = 2 THEN driver_id END), 2) AS "50%",
    ROUND(MAX(CASE WHEN q_id = 3 THEN driver_id END), 2) AS "75%",
    ROUND(MAX(driver_id), 2) AS max
FROM quartiles

UNION ALL

SELECT 
    'vehicle_year' AS column_name,
    COUNT(vehicle_year),
    COUNT(DISTINCT vehicle_year),
    ROUND(AVG(vehicle_year), 1),
    ROUND(MIN(vehicle_year), 1),
    ROUND(MAX(CASE WHEN q_year = 1 THEN vehicle_year END), 1),
    ROUND(MAX(CASE WHEN q_year = 2 THEN vehicle_year END), 1),
    ROUND(MAX(CASE WHEN q_year = 3 THEN vehicle_year END), 1),
    ROUND(MAX(vehicle_year), 1)
FROM quartiles

UNION ALL

SELECT 
    'rating' AS column_name,
    COUNT(rating),
    COUNT(DISTINCT rating),
    ROUND(AVG(rating), 2),
    ROUND(MIN(rating), 2),
    ROUND(MAX(CASE WHEN q_rating = 1 THEN rating END), 2),
    ROUND(MAX(CASE WHEN q_rating = 2 THEN rating END), 2),
    ROUND(MAX(CASE WHEN q_rating = 3 THEN rating END), 2),
    ROUND(MAX(rating), 2)
FROM quartiles

UNION ALL

SELECT 
    'is_active' AS column_name,
    COUNT(is_active),
    COUNT(DISTINCT is_active),
    ROUND(AVG(is_active), 2),
    ROUND(MIN(is_active), 2),
    ROUND(MAX(CASE WHEN q_active = 1 THEN is_active END), 2),
    ROUND(MAX(CASE WHEN q_active = 2 THEN is_active END), 2),
    ROUND(MAX(CASE WHEN q_active = 3 THEN is_active END), 2),
    ROUND(MAX(is_active), 2)
FROM quartiles

UNION ALL

SELECT 
    'years_driving' AS column_name,
    COUNT(years_driving),
    COUNT(DISTINCT years_driving),
    ROUND(AVG(years_driving), 2),
    ROUND(MIN(years_driving), 2),
    ROUND(MAX(CASE WHEN q_years = 1 THEN years_driving END), 2),
    ROUND(MAX(CASE WHEN q_years = 2 THEN years_driving END), 2),
    ROUND(MAX(CASE WHEN q_years = 3 THEN years_driving END), 2),
    ROUND(MAX(years_driving), 2)
FROM quartiles;

-- riders overview:
-- 400 unique drivers
-- dataset covers vehicles from a 12 year span
-- mean rating is 4.15 while the minimal is 2.59
-- mean years driving is 1.81. Most drivers have under 3 years and the max is 4 years

-- riders
SELECT * FROM riders;

-- riders summary
WITH base_riders AS (
    SELECT 
        rider_id,
        rating,
        total_trips,
        CAST((julianday((SELECT MAX(created_at) FROM riders)) - julianday(created_at)) / 365.25 AS INTEGER) AS rider_since_years
    FROM riders
),
quartiles AS (
    SELECT 
        rider_id,
        rating,
        total_trips,
        rider_since_years,
        NTILE(4) OVER (ORDER BY rider_id) AS q_id,
        NTILE(4) OVER (ORDER BY rating) AS q_rating,
        NTILE(4) OVER (ORDER BY total_trips) AS q_trips,
        NTILE(4) OVER (ORDER BY rider_since_years) AS q_since
    FROM base_riders
)
SELECT 
    'rider_id' AS column_name,
    COUNT(rider_id) AS count,
    COUNT(DISTINCT rider_id) AS distinct_count,
    ROUND(AVG(rider_id), 2) AS mean,
    ROUND(MIN(rider_id), 2) AS min,
    ROUND(MAX(CASE WHEN q_id = 1 THEN rider_id END), 2) AS "25%",
    ROUND(MAX(CASE WHEN q_id = 2 THEN rider_id END), 2) AS "50%",
    ROUND(MAX(CASE WHEN q_id = 3 THEN rider_id END), 2) AS "75%",
    ROUND(MAX(rider_id), 2) AS max
FROM quartiles

UNION ALL

SELECT 
    'rating' AS column_name,
    COUNT(rating),
    COUNT(DISTINCT rating),
    ROUND(AVG(rating), 2),
    ROUND(MIN(rating), 2),
    ROUND(MAX(CASE WHEN q_rating = 1 THEN rating END), 2),
    ROUND(MAX(CASE WHEN q_rating = 2 THEN rating END), 2),
    ROUND(MAX(CASE WHEN q_rating = 3 THEN rating END), 2),
    ROUND(MAX(rating), 2)
FROM quartiles

UNION ALL

SELECT 
    'total_trips' AS column_name,
    COUNT(total_trips),
    COUNT(DISTINCT total_trips),
    ROUND(AVG(total_trips), 2),
    ROUND(MIN(total_trips), 2),
    ROUND(MAX(CASE WHEN q_trips = 1 THEN total_trips END), 2),
    ROUND(MAX(CASE WHEN q_trips = 2 THEN total_trips END), 2),
    ROUND(MAX(CASE WHEN q_trips = 3 THEN total_trips END), 2),
    ROUND(MAX(total_trips), 2)
FROM quartiles

UNION ALL

SELECT 
    'rider_since_years' AS column_name,
    COUNT(rider_since_years),
    COUNT(DISTINCT rider_since_years),
    ROUND(AVG(rider_since_years), 2),
    ROUND(MIN(rider_since_years), 2),
    ROUND(MAX(CASE WHEN q_since = 1 THEN rider_since_years END), 2),
    ROUND(MAX(CASE WHEN q_since = 2 THEN rider_since_years END), 2),
    ROUND(MAX(CASE WHEN q_since = 3 THEN rider_since_years END), 2),
    ROUND(MAX(rider_since_years), 2)
FROM quartiles;

-- riders overview:
-- 1600 riders
-- mean rating of 3.99
-- mean ammounts of trips of 10.52
--

-- locations
SELECT * FROM locations;

-- summary
WITH categorical_summary AS (
    -- 1. USERS: City Distribution
    SELECT 
        'users' AS table_name,
        'city' AS column_name,
        city AS category_value,
        COUNT(*) AS count
    FROM users
    GROUP BY city

    UNION ALL

    -- 2. DRIVERS: Vehicle Make Distribution
    SELECT 
        'drivers',
        'vehicle_make',
        vehicle_make,
        COUNT(*)
    FROM drivers
    GROUP BY vehicle_make

    UNION ALL

    -- 3. TRIPS: Status Distribution
    SELECT 
        'trips',
        'status',
        status,
        COUNT(*)
    FROM trips
    GROUP BY status

    UNION ALL

    -- 4. TRIPS: Payment Method Distribution
    SELECT 
        'trips',
        'payment_method',
        payment_method,
        COUNT(*)
    FROM trips
    GROUP BY payment_method

    UNION ALL

    -- 5. PAYMENTS: Method Distribution
    SELECT 
        'payments',
        'method',
        method,
        COUNT(*)
    FROM payments
    GROUP BY method

    UNION ALL

    -- 6. PAYMENTS: Status Distribution
    SELECT 
        'payments',
        'status',
        status,
        COUNT(*)
    FROM payments
    GROUP BY status

    UNION ALL

    -- 7. CANCELLATIONS: Cancelled By Distribution
    SELECT 
        'cancellations',
        'cancelled_by',
        cancelled_by,
        COUNT(*)
    FROM cancellations
    GROUP BY cancelled_by

    UNION ALL

    -- 8. LOCATIONS: Zone Type Distribution
    SELECT 
        'locations',
        'zone_type',
        zone_type,
        COUNT(*)
    FROM locations
    GROUP BY zone_type
)

SELECT 
    table_name,
    column_name,
    category_value,
    count,
    ROUND(count * 100.0 / SUM(count) OVER (PARTITION BY table_name, column_name), 2) || '%' AS percentage
FROM categorical_summary
ORDER BY 
    table_name, 
    column_name, 
    count DESC;


-- trips
SELECT * FROM trips;

-- trip distribution overview
SELECT * FROM trips;

-- trip distribution overview
-- maps the volume of completed trips across distance, duration, and time of day, including average metrics

WITH trip_distributions AS (
    SELECT
        distance_km,
        duration_mins,
        CAST(strftime('%H', requested_at) AS INTEGER) AS hour_of_day,
        total_fare,
        surge_multiplier,
        -- base profit calculation (fare minus $2 fixed fee minus variable uber cut)
        (total_fare - 2.00) - ((total_fare - 2.00) * CASE 
            WHEN distance_km < 5 THEN 0.20
            WHEN distance_km >= 5 AND distance_km < 20 THEN 0.30
            ELSE 0.45
        END) AS real_profit
    FROM trips
    WHERE status = 'completed' AND total_fare > 2.00
),
distance_buckets AS (
    SELECT
        'distance' AS distribution_type,
        CASE
            WHEN distance_km < 2 THEN '1. under 2 km'
            WHEN distance_km >= 2 AND distance_km < 5 THEN '2. 2-5 km'
            WHEN distance_km >= 5 AND distance_km < 10 THEN '3. 5-10 km'
            WHEN distance_km >= 10 AND distance_km < 20 THEN '4. 10-20 km'
            ELSE '5. 20+ km'
        END AS category,
        COUNT(*) AS trip_count,
        ROUND(AVG(total_fare), 2) AS avg_fare,
        ROUND(AVG(duration_mins), 2) AS avg_duration_mins,
        ROUND(AVG(surge_multiplier), 2) AS avg_multiplier,
        ROUND(AVG(distance_km), 2) AS avg_distance_km,
        ROUND(AVG(total_fare / NULLIF(distance_km, 0)), 2) AS avg_fare_per_km,
        -- new column inserted
        ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
    FROM trip_distributions
    GROUP BY category
),
duration_buckets AS (
    SELECT
        'duration' AS distribution_type,
        CASE
            WHEN duration_mins < 10 THEN '1. under 10 mins'
            WHEN duration_mins >= 10 AND duration_mins < 20 THEN '2. 10-20 mins'
            WHEN duration_mins >= 20 AND duration_mins < 30 THEN '3. 20-30 mins'
            WHEN duration_mins >= 30 AND duration_mins < 45 THEN '4. 30-45 mins'
            ELSE '5. 45+ mins'
        END AS category,
        COUNT(*) AS trip_count,
        ROUND(AVG(total_fare), 2) AS avg_fare,
        ROUND(AVG(duration_mins), 2) AS avg_duration_mins,
        ROUND(AVG(surge_multiplier), 2) AS avg_multiplier,
        ROUND(AVG(distance_km), 2) AS avg_distance_km,
        ROUND(AVG(total_fare / NULLIF(distance_km, 0)), 2) AS avg_fare_per_km,
        -- new column inserted
        ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
    FROM trip_distributions
    GROUP BY category
),
time_of_day_buckets AS (
    SELECT
        'time_of_day' AS distribution_type,
        CASE
            WHEN hour_of_day >= 5 AND hour_of_day < 9 THEN '1. early morning (05:00-08:59)'
            WHEN hour_of_day >= 9 AND hour_of_day < 12 THEN '2. morning (09:00-11:59)'
            WHEN hour_of_day >= 12 AND hour_of_day < 15 THEN '3. mid day (12:00-14:59)'
            WHEN hour_of_day >= 15 AND hour_of_day < 18 THEN '4. afternoon (15:00-17:59)'
            WHEN hour_of_day >= 18 AND hour_of_day < 22 THEN '5. evening (18:00-21:59)'
            ELSE '6. late evening/night (22:00-04:59)'
        END AS category,
        COUNT(*) AS trip_count,
        ROUND(AVG(total_fare), 2) AS avg_fare,
        ROUND(AVG(duration_mins), 2) AS avg_duration_mins,
        ROUND(AVG(surge_multiplier), 2) AS avg_multiplier,
        ROUND(AVG(distance_km), 2) AS avg_distance_km,
        ROUND(AVG(total_fare / NULLIF(distance_km, 0)), 2) AS avg_fare_per_km,
        -- new column inserted
        ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
    FROM trip_distributions
    GROUP BY category
)

SELECT 
    distribution_type,
    category,
    trip_count,
    ROUND(trip_count * 100.0 / SUM(trip_count) OVER (PARTITION BY distribution_type), 2) || '%' AS percentage,
    avg_fare,
    avg_duration_mins,
    avg_multiplier,
    avg_distance_km,
    avg_fare_per_km,
    real_profit_per_hour
FROM distance_buckets

UNION ALL

SELECT 
    distribution_type,
    category,
    trip_count,
    ROUND(trip_count * 100.0 / SUM(trip_count) OVER (PARTITION BY distribution_type), 2) || '%' AS percentage,
    avg_fare,
    avg_duration_mins,
    avg_multiplier,
    avg_distance_km,
    avg_fare_per_km,
    real_profit_per_hour
FROM duration_buckets

UNION ALL

SELECT 
    distribution_type,
    category,
    trip_count,
    ROUND(trip_count * 100.0 / SUM(trip_count) OVER (PARTITION BY distribution_type), 2) || '%' AS percentage,
    avg_fare,
    avg_duration_mins,
    avg_multiplier,
    avg_distance_km,
    avg_fare_per_km,
    real_profit_per_hour
FROM time_of_day_buckets;


-- trips overview
-- short and quick trips are the most profitable
-- early morning and afternoon to night are the most profitable hours
-- 

-- reviews
SELECT * FROM reviews;

-- reviews summary
WITH categorical_summary AS (
    SELECT 
        'reviews' AS table_name,
        'rating' AS column_name,
        CAST(rating AS VARCHAR) AS category_value,
        COUNT(*) AS count
    FROM reviews
    GROUP BY rating
    
    UNION ALL
    
    SELECT 
        'reviews' AS table_name,
        'comment' AS column_name,
        COALESCE(comment, 'NULL') AS category_value,
        COUNT(*) AS count
    FROM reviews
    GROUP BY comment
)
SELECT 
    table_name,
    column_name,
    category_value,
    count,
    ROUND(count * 100.0 / SUM(count) OVER (PARTITION BY table_name, column_name), 2) || '%' AS percentage
FROM categorical_summary
ORDER BY 
    column_name,
    count DESC;

-- reviews overview:
-- most users skip comments
-- most ratings are high
-- time and routing  complaining are very common
-- car condition complaints are common

-- cancellations
SELECT * FROM cancellations;

-- summary
WITH categorical_summary AS (
    SELECT 
        'cancellations' AS table_name,
        'cancelled_by' AS column_name,
        COALESCE(cancelled_by, 'NULL') AS category_value,
        COUNT(*) AS count
    FROM cancellations
    GROUP BY cancelled_by
    
    UNION ALL
    
    SELECT 
        'cancellations' AS table_name,
        'reason' AS column_name,
        COALESCE(reason, 'NULL') AS category_value,
        COUNT(*) AS count
    FROM cancellations
    GROUP BY reason
)
SELECT 
    table_name,
    column_name,
    category_value,
    count,
    ROUND(count * 100.0 / SUM(count) OVER (PARTITION BY table_name, column_name), 2) || '%' AS percentage
FROM categorical_summary
ORDER BY 
    column_name,
    count DESC;

-- cancelations overview:
-- riders cancel most trips
-- personal emergencies lead reasons
-- long waits are second
-- drivers cancell much less


-- most profitable drivers
WITH driver_base_stats AS (
    SELECT
        t.driver_id,
        MAX(l.city) AS primary_city,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(p.amount, 0) ELSE 0 END) AS total_fare,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(t.distance_km, 0) ELSE 0 END) AS total_distance,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(t.duration_mins, 0) ELSE 0 END) AS total_duration,
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END) AS total_trips,
        AVG(CASE WHEN t.status = 'completed' THEN t.surge_multiplier END) AS avg_multiplier
    FROM trips t
    LEFT JOIN payments p ON t.trip_id = p.trip_id AND p.status = 'success'
    LEFT JOIN locations l ON t.pickup_location_id = l.location_id
    WHERE t.driver_id IS NOT NULL
    GROUP BY t.driver_id
),
daily_revenue AS (
    SELECT
        t.driver_id,
        CAST(strftime('%w', t.requested_at) AS INTEGER) AS dow_num,
        SUM(COALESCE(p.amount, 0)) AS revenue
    FROM trips t
    LEFT JOIN payments p ON t.trip_id = p.trip_id AND p.status = 'success'
    WHERE t.driver_id IS NOT NULL AND t.status = 'completed'
    GROUP BY t.driver_id, dow_num
),
ranked_days AS (
    SELECT
        driver_id,
        CASE dow_num
            WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END AS best_day_of_week,
        ROW_NUMBER() OVER(PARTITION BY driver_id ORDER BY revenue DESC) AS rnk
    FROM daily_revenue
)
SELECT
    bs.driver_id,
    bs.primary_city,
    ROUND(bs.total_distance / NULLIF(bs.total_trips, 0), 2) AS avg_distance_per_trip,
    ROUND(bs.total_duration * 1.0 / NULLIF(bs.total_trips, 0), 2) AS avg_time_per_trip,
    ROUND((bs.total_distance * 1.0 / NULLIF(bs.total_duration, 0)) * 60, 2) AS avg_speed_kmh,
    ROUND(bs.total_fare / NULLIF(bs.total_distance, 0), 2) AS profit_per_km,
    ROUND(bs.total_fare / NULLIF(bs.total_duration / 60.0, 0), 2) AS profit_per_hour,
    ROUND(bs.total_trips / NULLIF(bs.total_duration / 60.0, 0), 2) AS trips_per_hour,
    ROUND(bs.total_fare / NULLIF(bs.total_trips, 0), 2) AS avg_fare_per_trip,
    ROUND(bs.avg_multiplier, 2) AS avg_multiplier,
    rd.best_day_of_week AS most_profitable_day
FROM driver_base_stats bs
LEFT JOIN ranked_days rd ON bs.driver_id = rd.driver_id AND rd.rnk = 1
WHERE bs.total_trips > 0
ORDER BY profit_per_hour DESC;


