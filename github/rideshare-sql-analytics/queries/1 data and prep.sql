


-- locations:

SELECT * FROM locations;

DROP VIEW IF EXISTS stg_locations;

CREATE VIEW stg_locations AS
SELECT 
    location_id,
    LOWER(TRIM(zone_name)),
    LOWER(TRIM(city)),
    CAST(latitude AS REAL),
    CAST(longitude AS REAL),
    COALESCE(LOWER(TRIM(zone_type)), 'UNKNOWN_ZONE')
FROM locations;

SELECT * FROM stg_locations;

-- riders:

SELECT * FROM riders;

DROP VIEW IF EXISTS stg_riders;

CREATE VIEW stg_riders AS
SELECT 
    rider_id,
    user_id,
    rating,
    ABS(total_trips),
    DATE(created_at)
FROM riders;

SELECT * FROM stg_riders;

-- drivers:

SELECT * FROM drivers;

DROP VIEW IF EXISTS stg_drivers;

CREATE VIEW stg_drivers AS
SELECT 
    driver_id,
    user_id,
    vehicle_make,
    vehicle_model
    vehicle_year,
    license_plate,
    rating,
    DATE(join_date),
    is_active
FROM drivers;

SELECT * FROM stg_drivers;

-- cancellations:

SELECT * FROM cancellations;

DROP VIEW IF EXISTS stg_cancellations;

CREATE VIEW stg_cancellations AS
SELECT 
    cancel_id,
    trip_id,
    LOWER(TRIM(cancelLed_by)),
    COALESCE(LOWER(TRIM(reason)), 'REASON_NOT_PROVIDED'),
    DATETIME(cancelled_at)
FROM cancellations;

SELECT * FROM stg_cancellations;

-- payments:

SELECT * FROM payments;

DROP VIEW IF EXISTS stg_payments;

CREATE VIEW stg_payments AS
SELECT 
    payment_id,
    trip_id,
    amount,
    method,
    status,
    DATETIME(paid_at)
FROM payments;

SELECT * FROM stg_payments;

-- rides

SELECT * FROM rides;

DROP VIEW IF EXISTS stg_rides;

CREATE VIEW stg_rides AS
SELECT 
    ride_id,
    rider_id,
    driver_id,
    pickup_location_id,
    dropoff_location_id,
    
    -- Standardize all timestamps
    DATETIME(request_time) AS request_time_clean,
    DATETIME(pickup_time) AS pickup_time_clean,
    DATETIME(dropoff_time) AS dropoff_time_clean,
    
    -- Absolute value to fix potential sensor/GPS data entry errors
    ABS(distance_miles) AS distance_miles_clean,
    
    -- Standardize statuses
    LOWER(TRIM(ride_status)) AS ride_status_clean,
    
    -- If surge multiplier is null, it means base rate (1.0x)
    COALESCE(surge_multiplier, 1.0) AS surge_multiplier_clean

FROM rides
-- Hard filter. Remove entirely corrupted rows where critical FKs are missing
WHERE rider_id IS NOT NULL 
  AND driver_id IS NOT NULL;



-- STEP 7. CONSOLIDATED MASTER ANALYTICAL TABLE
-- Operations. Join all staged (cleaned) tables, apply logic validations.

DROP VIEW IF EXISTS vw_master_rideshare_clean;
CREATE VIEW vw_master_rideshare_clean AS
SELECT 
    -- IDs
    r.ride_id,
    r.rider_id,
    r.driver_id,
    
    -- Locations
    lp.city_clean AS pickup_city,
    lp.zone_name_clean AS pickup_zone,
    ld.city_clean AS dropoff_city,
    ld.zone_name_clean AS dropoff_zone,
    
    -- Timestamps
    r.request_time_clean,
    r.pickup_time_clean,
    r.dropoff_time_clean,
    
    -- Distance & Time Validations
    r.distance_miles_clean,
    CASE 
        WHEN r.pickup_time_clean IS NOT NULL AND r.dropoff_time_clean IS NOT NULL 
        THEN (julianday(r.dropoff_time_clean) - julianday(r.pickup_time_clean)) * 24 * 60 
        ELSE 0 
    END AS duration_minutes,
    
    -- Status
    r.ride_status_clean,
    
    -- Driver & Rider Demographics/Scores
    rd.rider_rating_clean,
    d.driver_rating_clean,
    d.vehicle_type_clean,
    
    -- Financials (From Payments)
    r.surge_multiplier_clean,
    COALESCE(p.fare_amount_clean, 0.0) AS fare_amount,
    COALESCE(p.tip_amount_clean, 0.0) AS tip_amount,
    COALESCE(p.tolls_amount_clean, 0.0) AS tolls_amount,
    (COALESCE(p.fare_amount_clean, 0.0) + COALESCE(p.tip_amount_clean, 0.0) + COALESCE(p.tolls_amount_clean, 0.0)) AS total_paid,
    COALESCE(p.payment_type_clean, 'UNKNOWN') AS payment_type,
    COALESCE(p.payment_status_clean, 'PENDING') AS payment_status,
    
    -- Cancellations (Left Join, will be NULL if not canceled)
    c.canceled_by_clean,
    c.cancellation_reason_clean

FROM stg_rides r
LEFT JOIN stg_riders rd ON r.rider_id = rd.rider_id
LEFT JOIN stg_drivers d ON r.driver_id = d.driver_id
LEFT JOIN stg_locations lp ON r.pickup_location_id = lp.location_id
LEFT JOIN stg_locations ld ON r.dropoff_location_id = ld.location_id
LEFT JOIN stg_payments p ON r.ride_id = p.ride_id
LEFT JOIN stg_cancellations c ON r.ride_id = c.ride_id

-- Final validity check. duration cannot be negative
WHERE (r.pickup_time_clean IS NULL OR r.dropoff_time_clean IS NULL OR julianday(r.dropoff_time_clean) >= julianday(r.pickup_time_clean));