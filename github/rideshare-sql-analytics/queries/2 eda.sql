-- to do

-- find what are the riders that
-- have the biggest fare count and smaller km and time
-- understand the profile of high profitability trips
-- test the correlation between profitable trips and profitable drivers



-- eda and summary statistics

-- users
SELECT * FROM users;

-- summary
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

-- summary
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

-- trips overview
-- ~70% of trips are cancelled by the rider
-- residential and commercial zones represent ~73% of locations
-- payment methods are mostly evenly distributed
-- over 97% of payments are successful
-- cities volumes are mostly evenly distributed

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
WITH dataset_end AS (
    SELECT MAX(requested_at) AS current_timestamp FROM trips
),
driver_stats AS (
    SELECT 
        t.driver_id,
        
        -- 1 DAY METRICS
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-1 days') THEN COALESCE(p.amount, 0) ELSE 0 END) AS money_1d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-1 days') THEN COALESCE(t.distance_km, 0) ELSE 0 END) AS range_1d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-1 days') THEN COALESCE(t.duration_mins, 0) ELSE 0 END) AS time_1d,
        COUNT(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-1 days') AND t.status = 'completed' THEN 1 END) AS trips_1d,
        
        -- 7 DAY METRICS
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-7 days') THEN COALESCE(p.amount, 0) ELSE 0 END) AS money_7d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-7 days') THEN COALESCE(t.distance_km, 0) ELSE 0 END) AS range_7d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-7 days') THEN COALESCE(t.duration_mins, 0) ELSE 0 END) AS time_7d,
        COUNT(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-7 days') AND t.status = 'completed' THEN 1 END) AS trips_7d,
        
        -- 30 DAY METRICS
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-30 days') THEN COALESCE(p.amount, 0) ELSE 0 END) AS money_30d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-30 days') THEN COALESCE(t.distance_km, 0) ELSE 0 END) AS range_30d,
        SUM(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-30 days') THEN COALESCE(t.duration_mins, 0) ELSE 0 END) AS time_30d,
        COUNT(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-30 days') AND t.status = 'completed' THEN 1 END) AS trips_30d,
        
        -- TOTALS
        COUNT(CASE WHEN t.requested_at >= datetime(de.current_timestamp, '-30 days') AND c.cancel_id IS NOT NULL THEN 1 END) AS total_cancellations,
        MAX(l.city) AS primary_city
        
    FROM dataset_end de
    JOIN trips t ON t.requested_at >= datetime(de.current_timestamp, '-30 days')
    LEFT JOIN payments p ON t.trip_id = p.trip_id AND p.status = 'success'
    LEFT JOIN cancellations c ON t.trip_id = c.trip_id
    LEFT JOIN locations l ON t.pickup_location_id = l.location_id
    WHERE t.driver_id IS NOT NULL
    GROUP BY t.driver_id
)
SELECT 
    ds.driver_id,
    d.vehicle_make || ' ' || d.vehicle_model || ' (' || d.vehicle_year || ')' AS vehicle,
    d.rating AS driver_rating,
    ds.primary_city,
    
    -- MONEY
    ROUND(ds.money_1d, 2) AS money_1d,
    ROUND(ds.money_7d, 2) AS money_7d,
    ROUND(ds.money_30d, 2) AS money_30d,
    
    -- TRIPS
    ds.trips_1d,
    ds.trips_7d,
    ds.trips_30d,
    
    -- RANGE
    ROUND(ds.range_1d, 2) AS range_1d,
    ROUND(ds.range_7d, 2) AS range_7d,
    ROUND(ds.range_30d, 2) AS range_30d,

    -- TIME
    ds.time_1d AS mins_1d,
    ds.time_7d AS mins_7d,
    ds.time_30d AS mins_30d,
    
    -- PERFORMANCE INDICATORS (30-DAY BASIS)
    ds.total_cancellations,
    ROUND((ds.range_30d * 1.0 / NULLIF(ds.time_30d, 0)) * 60, 2) AS avg_speed_kmh,
    ROUND(ds.money_30d / NULLIF(ds.range_30d, 0), 2) AS profit_per_km,
    ROUND(ds.money_30d / NULLIF(ds.time_30d / 60.0, 0), 2) AS profit_per_hr
    
FROM driver_stats ds
JOIN drivers d ON ds.driver_id = d.driver_id
ORDER BY 
    ds.money_30d DESC, 
    ds.range_30d ASC;

-- most profitable drivers:
-- high volume + high efficency
-- steady, moderate traffic balacing time and distance
-- top drivers usually dont take anything under $2/km
-- 30-45 km/h for average speed (avoid highways and heavy traffic)
-- trips under 25 minutes

-- ==============================================================================
-- RIDER PROFITABILITY PROFILE: THE "WHALE" HUNT (30-DAY WINDOW)
-- Identifies the most lucrative customers based on their time/distance efficiency
-- ==============================================================================

WITH dataset_end AS (
    SELECT MAX(requested_at) AS current_timestamp FROM trips
),
rider_stats AS (
    SELECT 
        t.rider_id,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(p.amount, 0) ELSE 0 END) AS money_spent_30d,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(t.distance_km, 0) ELSE 0 END) AS range_30d,
        SUM(CASE WHEN t.status = 'completed' THEN COALESCE(t.duration_mins, 0) ELSE 0 END) AS time_30d,
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END) AS trips_30d,
        COUNT(CASE WHEN c.cancelled_by = 'rider' THEN 1 END) AS rider_cancellations
    FROM dataset_end de
    JOIN trips t ON t.requested_at >= datetime(de.current_timestamp, '-30 days')
    LEFT JOIN payments p ON t.trip_id = p.trip_id AND p.status = 'success'
    LEFT JOIN cancellations c ON t.trip_id = c.trip_id
    GROUP BY t.rider_id
)
SELECT 
    rs.rider_id,
    u.city AS primary_city,
    r.rating AS rider_rating,
    CAST((julianday((SELECT current_timestamp FROM dataset_end)) - julianday(r.created_at)) / 365.25 AS INTEGER) AS account_age_yrs,
    r.total_trips AS lifetime_trips,
    rs.trips_30d,
    ROUND(rs.money_spent_30d, 2) AS total_spent_30d,
    ROUND(rs.range_30d, 2) AS total_range_30d,
    rs.time_30d AS total_mins_30d,
    rs.rider_cancellations,
    -- EFFICIENCY METRICS
    ROUND((rs.range_30d * 1.0 / NULLIF(rs.time_30d, 0)) * 60, 2) AS avg_speed_kmh,
    ROUND(rs.money_spent_30d / NULLIF(rs.range_30d, 0), 2) AS yield_per_km,
    ROUND(rs.money_spent_30d / NULLIF(rs.time_30d / 60.0, 0), 2) AS yield_per_hr
FROM rider_stats rs
JOIN riders r ON rs.rider_id = r.rider_id
JOIN users u ON r.user_id = u.user_id
WHERE rs.trips_30d > 0
ORDER BY 
    yield_per_hr DESC, 
    rs.money_spent_30d DESC;

    -- ==============================================================================
-- TL;DR RIDER STRATEGY
-- ==============================================================================

-- * BAD RATINGS PAY WELL
--   Stop ignoring low ratings. Rider 1018 (3.12 rating) yielded $130/hr. 

-- * SHORT & EXPENSIVE WINS
--   High turnover beats long trips. Rider 1565 hit $350/hr on a single quick trip.

-- * $2/KM IS THE BARE MINIMUM
--   Page 1 whales pay $3.00 to $7.00+ per km. Page 3 drops to $1.50/km. Reject the cheap ones.

-- * VETERANS AREN'T BETTER
--   Rider 1427 (14 lifetime trips) yielded $202/hr. Account age doesn't equal more money.



-- ==============================================================================
-- META STRATEGY: THE "ALPHA" SCHEDULE PER DRIVER
-- Eliminates noise by isolating specific drivers who dominate certain hours.
-- ==============================================================================

WITH trip_metrics AS (
    SELECT 
        t.driver_id,
        CASE CAST(strftime('%w', t.requested_at) AS INTEGER)
            WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' 
            WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' 
            WHEN 6 THEN 'Saturday' 
        END AS day_of_week,
        CAST(strftime('%H', t.requested_at) AS INTEGER) AS hour_of_day,
        p.amount,
        t.distance_km,
        t.duration_mins
    FROM trips t
    JOIN payments p ON t.trip_id = p.trip_id AND p.status = 'success'
    WHERE t.status = 'completed'
)
SELECT 
    driver_id,
    day_of_week,
    hour_of_day,
    COUNT(*) AS total_trips,
    ROUND(SUM(amount), 2) AS total_fare,
    ROUND(SUM(distance_km), 2) AS total_distance,
    SUM(duration_mins) AS total_time_mins,
    ROUND(SUM(amount) / NULLIF(SUM(distance_km), 0), 2) AS yield_per_km,
    ROUND(SUM(amount) / NULLIF(SUM(duration_mins) / 60.0, 0), 2) AS yield_per_hr
FROM trip_metrics
GROUP BY driver_id, day_of_week, hour_of_day
HAVING total_trips > 1  -- Filters out lucky "one-off" high-fare pings
ORDER BY yield_per_hr DESC
LIMIT 30;

-- ==============================================================================
-- TL;DR META-OBSERVATIONS (DRIVER-SPECIFIC PATTERNS)
-- ==============================================================================

-- * THE COMMUTE SNIPER
--   Top drivers aren't working 12 hours. They own Wed/Thu/Fri 07:00-09:00.
--   They hit $130+/hr by catching premium airport/office runs and quitting before 10 AM.

-- * THE MID-WEEK DINNER PEAK
--   Wednesday 18:00-19:00 is a hidden goldmine. 
--   High total_fare ($72+) and consistent $3.70/km. These are likely 
--   middle-distance corporate dinners, not short bar hops.

-- * FRIDAY NIGHT SPECIALIZATION
--   Friday 17:00-22:00 shows the highest density of high-yield drivers.
--   This is "Surge Season." Drivers on Page 1 are likely ignoring all pings
--   that don't have a multiplier, maintaining that $3.50+/km floor.

-- * THE WEEKEND WARRIOR (Sat 23:00 - Sun 01:00)
--   High total_distance but extreme total_fare. 
--   Yield/Hr stays high because traffic vanishes, allowing for 
--   very fast trip turnover even if the distance is longer.

-- ==============================================================================
-- THE "SNIPER" META STRATEGY
-- Analyzing the top-performing individual sessions to define the ideal shift.
-- ==============================================================================

-- * THE "DOUBLE-RUN" 8 AM SPECIAL (Monday/Tuesday/Friday)
--   Top drivers like 142, 208, and 162 aren't doing 10 trips; they are doing 2.
--   Data: Driver 142 made $235.43 in just 8 minutes across 2 trips.
--   Strategy: High-value, short-duration "Whale" trips (Airport/Corporate) at 8 AM.
--   If you don't catch a $100+ trip by 8:15 AM, the window for $200+/hr is closed.

-- * THE MONDAY 5 PM SYNDICATE (Monday 17:00 - 19:00)
--   Consistency across multiple drivers (348, 31, 344) proves this isn't luck.
--   Data: Yields stay locked at $190-$210/hr with a $3.70 - $4.20/km floor.
--   Strategy: Use Monday evening as your primary "Revenue Anchor." Traffic is 
--   predictable, and surge demand is structural, not accidental.

-- * THE SATURDAY NIGHT SURGE (Saturday 23:00)
--   The "Late-Night Whale" exists.
--   Data: Driver 178 hit $199/hr while covering 67km. 
--   Strategy: This is for high-speed, long-distance trips. Unlike the 8 AM 
--   Snipers who want short/fast, the Saturday night meta is about clearing 
--   huge distances quickly while the roads are empty and the multiplier is on.

-- * THE "ONE AND DONE" EFFICIENCY
--   Drivers on this list have very low "total_time_mins" (many under 40 mins).
--   Strategy: These drivers likely "cherry-pick" from home or a staging area. 
--   They wait for the perfect signal (High Fare + Low Time) and go offline 
--   immediately after the high-value window closes to protect their average.