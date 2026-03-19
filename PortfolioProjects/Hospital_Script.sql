SELECT *
FROM patient.health;

SELECT *
FROM patient.demographics;

-- Demographics--
SELECT race,
		COUNT(*) as num_of_patients
FROM patient.demographics
WHERE race != "?"
GROUP BY race
ORDER BY 2 DESC;

SELECT gender,
		COUNT(*) as num_of_patients
FROM patient.demographics
WHERE race != "?"
GROUP BY gender
ORDER BY 2 DESC;

-- TOP 10 patients with the most hospital visits--
SELECT demographics.patient_nbr AS patient_nbr,
		COUNT(DISTINCT(health.encounter_id)) AS num_of_hospitalizations
FROM patient.demographics
JOIN patient.health
	ON demographics.patient_nbr = health.patient_nbr
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

-- Avg time in hospital by admission type--
SELECT admission_type_id,
		ROUND(AVG(time_in_hospital),2) AS avg_time_in_hosp
FROM health
GROUP BY 1
ORDER BY 1;

-- Histogram for time in hospital-- 
SELECT ROUND(time_in_hospital,1) AS bucket,
COUNT(*) AS count,
RPAD(" ", COUNT(*)/100, "*") AS bar
FROM patient.health
GROUP BY bucket
ORDER BY bucket;

-- Medical specialty highest procedures--  
SELECT medical_specialty,
ROUND(AVG(num_procedures),1) AS avg_procedures,
COUNT(*) AS count
FROM patient.health
WHERE medical_specialty != '?' 
GROUP BY medical_specialty 
HAVING COUNT(*) > 50 AND ROUND(AVG(num_procedures),1) >2.5
Order BY 2 DESC;

-- JOINS--  
SELECT * 
FROM patient.health
JOIN patient.demographics
	on health.patient_nbr = demographics.patient_nbr
LIMIT 10;

-- Distribution of lab procedures by race--  
SELECT demographics.race as 'race',
ROUND(AVG(health.num_lab_procedures),2) as 'average_num_lab_procedures'
FROM patient.health
JOIN patient.demographics
	on demographics.patient_nbr = health.patient_nbr
WHERE race != "?"
GROUP BY 1
ORDER BY 2 desc;

SELECT MAX(num_lab_procedures),
AVG(num_lab_procedures),
MIN(num_lab_procedures)
FROM patient.health;

-- Average hospital stay based on num_procedures--  
SELECT AVG(time_in_hospital) as avg_hospital_stay,
CASE
	WHEN num_lab_procedures <25 THEN "Few"
    WHEN num_lab_procedures <55 THEN "Average"
    ELSE "Many"
END as procedure_frequency
FROM health
GROUP BY procedure_frequency
ORDER BY 1 DESC;

-- Simple Unions--  
SELECT patient_nbr
FROM patient.demographics
WHERE race = "AfricanAmerican"
UNION
SELECT patient_nbr
FROM patient.health
WHERE metformin = "Up";


-- Hospital Success Stories
 
-- Subqueries--  
SELECT *
FROM patient.health
WHERE admission_type_id = 1 AND
time_in_hospital < (SELECT AVG(time_in_hospital) FROM health);

-- CTE--  
WITH avg_time
	AS (SELECT AVG(time_in_hospital) FROM health) 
SELECT * 
FROM patient.health 
WHERE admission_type_id = 1 AND 
time_in_hospital < (SELECT * FROM avg_time);

SELECT 
CONCAT('Patient ', health.patient_nbr, ' was ', demographics.race, ' and ', 
(CASE 
	WHEN readmitted = 'NO' THEN 'was not readmitted. They had ' 
    ELSE 'was readmitted. They had ' END), 
num_medications, ' medications and ', 
num_lab_procedures, ' lab procedures.' ) AS summary
FROM patient.health 
INNER JOIN patient.demographics 
	ON demographics.patient_nbr = health.patient_nbr 
ORDER BY num_medications DESC, 
	num_lab_procedures 
DESC LIMIT 50;

-- ALTER Tables--
ALTER TABLE health MODIFY COLUMN num_procedures int; 
ALTER TABLE health MODIFY COLUMN num_medications int;
ALTER TABLE health MODIFY COLUMN num_lab_procedures int;

-- Age Range with the most amount of patients by admission type
-- SELECT demographics.age,
--     health.admission_type_id,
--     COUNT(*) AS num_of_patients,
--     DENSE_RANK() OVER (PARTITION BY health.admission_type_id ORDER BY COUNT(*) DESC) as "rank"
-- FROM patient.demographics
-- JOIN patient.health
-- 	on health.patient_nbr = demographics.patient_nbr
-- GROUP BY 1, 2
-- -- HAVING "rank" = 1 

WITH temp
	AS (
		SELECT demographics.age,
    health.admission_type_id,
    COUNT(*) AS num_of_patients,
    DENSE_RANK() OVER (PARTITION BY health.admission_type_id ORDER BY COUNT(*) DESC) as "rank"
FROM patient.demographics
JOIN patient.health
	on health.patient_nbr = demographics.patient_nbr
GROUP BY 1, 2)
SELECT *
FROM temp
WHERE "rank" = 1


