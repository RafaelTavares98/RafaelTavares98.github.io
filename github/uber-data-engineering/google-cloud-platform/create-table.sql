CREATE OR REPLACE TABLE `uber-data-405421.uber_data_allysa.uber_analytics` AS
(
SELECT
f.VendorID,
d.tpep_pickup_datetime,
d.tpep_dropoff_datetime,
p.passenger_count,
t.trip_distance,
r.rate_code_name,
pick.pickup_latitude,
pick.pickup_longitude,
dropoff.dropoff_latitude,
dropoff.dropoff_longitude,
pay.payment_type_name,
f.fare_amount,
f.extra,
f.mta_tax,
f.tip_amount,
f.tolls_amount,
f.improvement_surcharge,
f.total_amount,

FROM `uber-data-405421.uber_data_allysa.fact_table` f
JOIN `uber-data-405421.uber_data_allysa.datetime_dim` d on f.datetime_id = d.datetime_id
JOIN `uber-data-405421.uber_data_allysa.passenger_count_dim` p on p.passenger_count_id = f.passenger_count_id
JOIN `uber-data-405421.uber_data_allysa.trip_distance_dim` t on t.trip_distance_id = f.trip_distance_id
JOIN `uber-data-405421.uber_data_allysa.rate_code_dim` r on r.rate_code_id = f.rate_code_id
JOIN `uber-data-405421.uber_data_allysa.pickup_location_dim` pick on pick.pickup_location_id = f.pickup_location_id
JOIN `uber-data-405421.uber_data_allysa.dropoff_location_dim` dropoff on dropoff.dropoff_location_id = f.dropoff_location_id
JOIN `uber-data-405421.uber_data_allysa.payment_type_dim` pay on pay.payment_type_id = f.payment_type_id)
;
