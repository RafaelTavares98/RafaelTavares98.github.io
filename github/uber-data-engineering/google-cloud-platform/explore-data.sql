SELECT VendorID, AVG(fare_amount) FROM `uber-data-405421.uber_data_allysa.fact_table`
GROUP BY VendorID;

SELECT VendorID, AVG(fare_amount) FROM `uber-data-405421.uber_data_allysa.fact_table`
GROUP BY VendorID;

SELECT B.payment_type_name, SUM(A.tip_amount) FROM `uber-data-405421.uber_data_allysa.fact_table` A
JOIN `uber-data-405421.uber_data_allysa.payment_type_dim` B
ON a.payment_type_id = B.payment_type_id
GROUP BY B.payment_type_name;

SELECT B.payment_type_name, AVG(A.tip_amount) FROM `uber-data-405421.uber_data_allysa.fact_table` A
JOIN `uber-data-405421.uber_data_allysa.payment_type_dim` B
ON a.payment_type_id = B.payment_type_id
GROUP BY B.payment_type_name;
