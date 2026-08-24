-- Establishing the platform baseline. This query provides a high-level overview of the ecosystem, evaluating city coverage, driver experience levels, and overall satisfaction ratings across the user base.
WITH platform_metrics AS (
    SELECT 
        COUNT(DISTINCT city) AS total_cities
    FROM users
),
driver_metrics AS (
    SELECT 
        ROUND(AVG((julianday((SELECT MAX(join_date) FROM drivers)) - julianday(join_date)) / 365.25), 2) AS avg_driver_tenure_years,
        ROUND(MAX((julianday((SELECT MAX(join_date) FROM drivers)) - julianday(join_date)) / 365.25), 2) AS max_driver_tenure_years,
        ROUND(AVG(rating), 2) AS avg_driver_rating,
        ROUND(MIN(rating), 2) AS min_driver_rating
    FROM drivers    
),
rider_metrics AS (
    SELECT 
        ROUND(AVG(total_trips), 2) AS avg_rider_trips,
        ROUND(AVG(rating), 2) AS avg_rider_rating
    FROM riders
)
SELECT 
    platform_metrics.total_cities,
    driver_metrics.avg_driver_tenure_years,
    driver_metrics.max_driver_tenure_years,
    driver_metrics.avg_driver_rating,
    driver_metrics.min_driver_rating,
    rider_metrics.avg_rider_trips,
    rider_metrics.avg_rider_rating
FROM platform_metrics, driver_metrics, rider_metrics;



-- Uncovering trip profitability. By segmenting completed rides based on distance, duration, and time of day, this analysis pinpoints exactly which operational conditions yield the highest real profit per hour.
WITH trip_data AS (
    SELECT 
        distance_km,
        duration_mins,
        CAST(strftime('%H', requested_at) AS INTEGER) AS hour_of_day,
        (total_fare - 2.00) - ((total_fare - 2.00) * CASE 
            WHEN distance_km < 5 THEN 0.20
            WHEN distance_km >= 5 AND distance_km < 20 THEN 0.30
            ELSE 0.45
        END) AS real_profit
    FROM trips
    WHERE status = 'completed' 
      AND total_fare > 2.00
)
SELECT 
    'Distance' AS category_type,
    CASE 
        WHEN distance_km < 5 THEN 'Under 5 km'
        WHEN distance_km >= 5 AND distance_km < 20 THEN '5 - 20 km'
        ELSE 'Over 20 km'
    END AS category_name,
    COUNT(*) AS trip_count,
    ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
FROM trip_data
GROUP BY category_name

UNION ALL

SELECT 
    'Duration' AS category_type,
    CASE 
        WHEN duration_mins < 20 THEN 'Under 20 mins'
        WHEN duration_mins >= 20 AND duration_mins < 40 THEN '20 - 40 mins'
        ELSE 'Over 40 mins'
    END AS category_name,
    COUNT(*) AS trip_count,
    ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
FROM trip_data
GROUP BY category_name

UNION ALL

SELECT 
    'Time of Day' AS category_type,
    CASE 
        WHEN hour_of_day >= 5 AND hour_of_day < 9 THEN 'Early Morning (05:00-08:59)'
        WHEN hour_of_day >= 18 OR hour_of_day < 5 THEN 'Evening to Night (18:00-04:59)'
        ELSE 'Midday (09:00-17:59)'
    END AS category_name,
    COUNT(*) AS trip_count,
    ROUND(AVG(real_profit / NULLIF(duration_mins / 60.0, 0)), 2) AS real_profit_per_hour
FROM trip_data
GROUP BY category_name;



-- Identifying friction points in the user experience. This section breaks down cancellation volumes by the initiating party and the stated reason, highlighting operational bottlenecks like excessive wait times.
SELECT 
    cancelled_by,
    reason,
    COUNT(cancel_id) AS cancellation_count
FROM cancellations
GROUP BY 
    cancelled_by, 
    reason
ORDER BY 
    cancellation_count DESC;



-- Profiling top-performing drivers. By grouping the fleet into profitability brackets, this query reveals the strategic behaviors of the highest earners, analyzing their preferred trip distances, optimal working hours, favorite operational zones, and tolerance for cancellations.
WITH driver_profit AS (
    SELECT
        trips.driver_id,
        COUNT(trips.trip_id) AS trips,
        SUM(trips.distance_km) AS dist_km,
        SUM(trips.duration_mins) AS dur_mins,
        SUM(
            (trips.total_fare - 2.00) - ((trips.total_fare - 2.00) * CASE
                WHEN trips.distance_km < 5 THEN 0.20
                WHEN trips.distance_km >= 5 AND trips.distance_km < 20 THEN 0.30
                ELSE 0.45
            END)
        ) AS profit,
        SUM(CASE WHEN trips.distance_km < 5 THEN 1 ELSE 0 END) AS t_under_5,
        SUM(CASE WHEN trips.distance_km >= 5 AND trips.distance_km < 10 THEN 1 ELSE 0 END) AS t_5_10,
        SUM(CASE WHEN trips.distance_km >= 10 AND trips.distance_km < 20 THEN 1 ELSE 0 END) AS t_10_20,
        SUM(CASE WHEN trips.distance_km >= 20 THEN 1 ELSE 0 END) AS t_over_20
    FROM trips
    WHERE trips.status = 'completed' AND trips.total_fare > 2.00
    GROUP BY trips.driver_id
    HAVING SUM(trips.duration_mins) > 0 AND SUM(trips.distance_km) > 0
),
driver_brackets AS (
    SELECT
        driver_profit.driver_id,
        driver_profit.trips,
        driver_profit.profit,
        driver_profit.t_under_5,
        driver_profit.t_5_10,
        driver_profit.t_10_20,
        driver_profit.t_over_20,
        (driver_profit.profit / (driver_profit.dur_mins / 60.0)) AS profit_hr,
        (driver_profit.profit / driver_profit.dist_km) AS profit_km,
        NTILE(100) OVER (ORDER BY (driver_profit.profit / (driver_profit.dur_mins / 60.0)) DESC) AS pct_rank
    FROM driver_profit
),
bracket_assignment AS (
    SELECT 
        driver_brackets.driver_id,
        driver_brackets.trips,
        driver_brackets.profit_hr,
        driver_brackets.profit_km,
        driver_brackets.t_under_5,
        driver_brackets.t_5_10,
        driver_brackets.t_10_20,
        driver_brackets.t_over_20,
        CASE 
            WHEN driver_brackets.pct_rank = 1 THEN '1. Top 1%'
            WHEN driver_brackets.pct_rank > 1 AND driver_brackets.pct_rank <= 5 THEN '2. 1% - 5%'
            WHEN driver_brackets.pct_rank > 5 AND driver_brackets.pct_rank <= 10 THEN '3. 5% - 10%'
            WHEN driver_brackets.pct_rank > 10 AND driver_brackets.pct_rank <= 50 THEN '4. 10% - 50%'
            ELSE '5. Bottom 50%'
        END AS tier
    FROM driver_brackets
),
bracket_summary AS (
    SELECT
        bracket_assignment.tier,
        ROUND(AVG(bracket_assignment.profit_hr), 2) AS profit_hr,
        ROUND(AVG(bracket_assignment.profit_km), 2) AS profit_km,
        ROUND(SUM(bracket_assignment.t_under_5) * 100.0 / SUM(bracket_assignment.trips), 2) AS pct_under_5km,
        ROUND(SUM(bracket_assignment.t_5_10) * 100.0 / SUM(bracket_assignment.trips), 2) AS pct_5_10km,
        ROUND(SUM(bracket_assignment.t_10_20) * 100.0 / SUM(bracket_assignment.trips), 2) AS pct_10_20km,
        ROUND(SUM(bracket_assignment.t_over_20) * 100.0 / SUM(bracket_assignment.trips), 2) AS pct_over_20km
    FROM bracket_assignment
    GROUP BY bracket_assignment.tier
),
bracket_extras AS (
    SELECT
        bracket_assignment.tier,
        trips.trip_id,
        trips.surge_multiplier,
        CAST(strftime('%H', trips.requested_at) AS INTEGER) AS hour,
        locations.zone_type,
        cancellations.cancel_id
    FROM bracket_assignment
    INNER JOIN trips 
        ON bracket_assignment.driver_id = trips.driver_id
    LEFT JOIN locations 
        ON trips.pickup_location_id = locations.location_id
    LEFT JOIN cancellations 
        ON trips.trip_id = cancellations.trip_id
),
bracket_metrics AS (
    SELECT
        bracket_extras.tier,
        ROUND(AVG(bracket_extras.surge_multiplier), 2) AS avg_multiplier,
        ROUND(COUNT(bracket_extras.cancel_id) * 100.0 / COUNT(bracket_extras.trip_id), 2) AS cancels_per_100
    FROM bracket_extras
    GROUP BY bracket_extras.tier
),
ranked_time AS (
    SELECT
        bracket_extras.tier,
        CASE
            WHEN bracket_extras.hour >= 5 AND bracket_extras.hour < 9 THEN '05:00-08:59'
            WHEN bracket_extras.hour >= 9 AND bracket_extras.hour < 12 THEN '09:00-11:59'
            WHEN bracket_extras.hour >= 12 AND bracket_extras.hour < 15 THEN '12:00-14:59'
            WHEN bracket_extras.hour >= 15 AND bracket_extras.hour < 18 THEN '15:00-17:59'
            WHEN bracket_extras.hour >= 18 AND bracket_extras.hour < 22 THEN '18:00-21:59'
            ELSE '22:00-04:59'
        END AS most_profitable_time,
        ROW_NUMBER() OVER(
            PARTITION BY bracket_extras.tier 
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM bracket_extras
    GROUP BY 
        bracket_extras.tier, 
        most_profitable_time
),
ranked_zone AS (
    SELECT
        bracket_extras.tier,
        bracket_extras.zone_type AS most_profitable_zone,
        ROW_NUMBER() OVER(
            PARTITION BY bracket_extras.tier 
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM bracket_extras
    WHERE bracket_extras.zone_type IS NOT NULL
    GROUP BY 
        bracket_extras.tier, 
        bracket_extras.zone_type
)

SELECT
    bracket_summary.tier AS profit_bracket,
    bracket_summary.profit_hr,
    bracket_summary.profit_km,
    bracket_summary.pct_under_5km || '%' AS pct_under_5km,
    bracket_summary.pct_5_10km || '%' AS pct_5_10km,
    bracket_summary.pct_10_20km || '%' AS pct_10_20km,
    bracket_summary.pct_over_20km || '%' AS pct_over_20km,
    bracket_metrics.avg_multiplier,
    bracket_metrics.cancels_per_100,
    ranked_time.most_profitable_time,
    ranked_zone.most_profitable_zone
FROM bracket_summary
INNER JOIN bracket_metrics 
    ON bracket_summary.tier = bracket_metrics.tier
INNER JOIN ranked_time 
    ON bracket_summary.tier = ranked_time.tier AND ranked_time.rn = 1
INNER JOIN ranked_zone 
    ON bracket_summary.tier = ranked_zone.tier AND ranked_zone.rn = 1
ORDER BY bracket_summary.tier ASC;