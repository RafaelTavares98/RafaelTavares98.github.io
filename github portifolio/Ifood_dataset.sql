SELECT *
FROM PortfolioProject4.dbo.ifood_data


--How kids and teens at home affect amount spent on wine
SELECT
	Kidhome,
	Teenhome,
	ROUND(AVG(MntWines),2) as avg_wine_spent,
	SUM(MntWines) as sum_wine_spent,
	COUNT(DISTINCT(family_id)) as num_of_families
FROM PortfolioProject4.dbo.ifood_data
GROUP BY
	Kidhome,
	Teenhome
ORDER BY
	avg_wine_spent DESC

--How education_level and marital status affect income
SELECT
	education_level,
	marital_status,
	ROUND(AVG(Age),0) as avg_age,
	ROUND(AVG(Income),2) as avg_income
FROM
	PortfolioProject4.dbo.ifood_data
GROUP BY 
	education_level,
	marital_status
ORDER BY
	avg_income DESC


--Created tables based with income brackets
With grouped_income AS(
SELECT
	*,
	CASE
		WHEN Income > 100000 THEN '120k-100k'
		WHEN Income > 80000 THEN '100k-80k'
		WHEN Income > 60000 THEN '80k-60k'
		WHEN Income > 40000 THEN '60k-40k'
		WHEN Income > 20000 THEN '40k-20k'
		ELSE 'Under 20k'
	END AS income_bracket

FROM
	PortfolioProject4.dbo.ifood_data)
--Income Brackets with percentages of grocery spending
SELECT
	income_bracket,
	ROUND(AVG(MntTotal),2) AS avg_spent,
	ROUND(AVG(Age),0) AS avg_age,
	(SUM(MntFishProducts)/SUM(MntTotal))*100 AS percent_fish,
	(SUM(MntFruits)/SUM(MntTotal))*100 AS percent_fruit,
	(SUM(MntGoldProds)/SUM(MntTotal))*100 AS percent_gold,
	(SUM(MntMeatProducts)/SUM(MntTotal))*100 AS percent_meat,
	(SUM(MntRegularProds)/SUM(MntTotal))*100 AS percent_regular,
	(SUM(MntSweetProducts)/SUM(MntTotal))*100 AS percent_sweets,
	(SUM(MntWines)/SUM(MntTotal))*100 AS percent_wine
FROM
	grouped_income
GROUP BY
	income_bracket
ORDER BY
	avg_spent DESC

--Bracketed Income and the average kids/teens at home
With grouped_income AS(
SELECT
	*,
	CASE
		WHEN Income > 100000 THEN '120k-100k'
		WHEN Income > 80000 THEN '100k-80k'
		WHEN Income > 60000 THEN '80k-60k'
		WHEN Income > 40000 THEN '60k-40k'
		WHEN Income > 20000 THEN '40k-20k'
		ELSE 'Under 20k'
	END AS income_bracket

FROM
	PortfolioProject4.dbo.ifood_data)
SELECT
	income_bracket,
	ROUND(AVG(kidhome),2) AS avg_kid,
	ROUND(AVG(teenhome),2) AS avg_teen,
	COUNT(DISTINCT(family_id)) as families_in_bracket

FROM
	grouped_income
GROUP BY
	income_bracket

--income brackets and  different purchasing methods
With grouped_income AS(
SELECT
	*,
	CASE
		WHEN Income > 100000 THEN '120k-100k'
		WHEN Income > 80000 THEN '100k-80k'
		WHEN Income > 60000 THEN '80k-60k'
		WHEN Income > 40000 THEN '60k-40k'
		WHEN Income > 20000 THEN '40k-20k'
		ELSE 'Under 20k'
	END AS income_bracket

FROM
	PortfolioProject4.dbo.ifood_data)
SELECT
	income_bracket,
	ROUND(AVG(Recency),0) AS avg_days_since_last_purchase,
	ROUND(AVG(NumDealsPurchases),1) AS avg_deal_purchases,
	ROUND(AVG(NumWebPurchases),1) AS avg_web_purchases,
	ROUND(AVG(NumCatalogPurchases),1) AS avg_catalog_purchases,
	ROUND(AVG(NumStorePurchases),1) AS avg_store_purchases,
	ROUND(AVG(NumWebVisitsMonth),1) AS avg_web_visits
FROM
	grouped_income
GROUP BY
	income_bracket



--income brackets and cost per store purchase
With grouped_income AS(
SELECT
	*,
	CASE
		WHEN Income > 100000 THEN '120k-100k'
		WHEN Income > 80000 THEN '100k-80k'
		WHEN Income > 60000 THEN '80k-60k'
		WHEN Income > 40000 THEN '60k-40k'
		WHEN Income > 20000 THEN '40k-20k'
		ELSE 'Under 20k'
	END AS income_bracket

FROM
	PortfolioProject4.dbo.ifood_data)

SELECT
	income_bracket,
	SUM(MntTotal) AS grocery_cost,
	SUM(NumStorePurchases) AS num_store_purchases,
	ROUND((SUM(Mnttotal)/SUM(NumStorePurchases)),2) AS avg_spent_store_purchase
FROM
	grouped_income
GROUP BY
	income_bracket
ORDER BY
	avg_spent_store_purchase

--Gold Purchases More than 50% of purchases, income related
SELECT
	family_id,
	income,
	(MntGoldProds/MntTotal) as gold_percent
FROM
	PortfolioProject4.dbo.ifood_data
WHERE
	(MntGoldProds/MntTotal) > .5 AND
	MntGoldProds < MntTotal

