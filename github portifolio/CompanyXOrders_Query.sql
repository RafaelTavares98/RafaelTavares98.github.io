SELECT *
FROM
	Orders as O
LEFT JOIN 
	Customers AS C
ON O.Customer_ID = C.Customer_ID

--Checking For Multiple Items in Single Order
SELECT 
	O.Customer_ID, 
	Count(O.Order_ID),
	COUNT(DISTINCT(O.Order_ID))
FROM
	Orders as O
LEFT JOIN 
	Customers AS C
ON O.Customer_ID = C.Customer_ID
GROUP BY
	O.Customer_ID
HAVING
	Count(O.Order_ID) != COUNT(DISTINCT(O.Order_ID))



--Number of Unique Customers
SELECT 
	COUNT(DISTINCT(Customer_ID)) AS Num_Customers,
	COUNT(DISTINCT(Order_ID)) AS Num_Orders,
	COUNT(DISTINCT(Order_ID)) - COUNT(DISTINCT(Customer_ID)) AS Repeat_Customer_Orders
FROM 
	Orders



--Orders and Sales By Country
SELECT 
	C.Country, 
	COUNT(DISTINCT(O.ORDER_ID)) As Num_Orders, 
	SUM(O.Net_Discount) AS Total_Sales,
	ROUND(SUM(O.Net_Discount)/ COUNT(DISTINCT(O.ORDER_ID)), 2) AS Average_Sale_Price
FROM 
	Orders AS O
LEFT JOIN 
	Customers AS C
ON O.Customer_ID = C.Customer_ID
WHERE
	C.Country IS NOT NULL
GROUP BY
	C.Country
ORDER BY
	Num_Orders DESC

--Top Customers By Number of Orders
SELECT 
	TOP 10 O.Customer_ID, COUNT(DISTINCT(O.Order_ID)) AS Num_Orders 
FROM 
	Orders AS O
LEFT JOIN 
	Customers AS C
ON O.Customer_ID = C.Customer_ID
GROUP BY
	O.Customer_ID
ORDER BY
	COUNT(O.Order_ID) DESC

--Number of Orders Per Month And Monthly Change
WITH Monthly_Orders AS
(
SELECT 
	YEAR, MONTH, COUNT(Order_ID) AS Num_Orders,
	COUNT(Order_ID)- LAG(COUNT(Order_ID),1,0) OVER (ORDER BY Year,MONTH) AS Monthly_Change
FROM 
	Orders
GROUP BY 
	Year,
	MONTH
--ORDER BY Year, MONTH
)
SELECT *,
	SUM(Num_Orders) OVER (Partition BY Year ORDER BY MONTH) AS Rolling_Yearly_Orders
FROM 
	Monthly_Orders

--Sales By Year
WITH Year_Sales AS
(
SELECT 
	Year,
	MONTH,
	SUM(Net_Discount) as Total_Sales,
	SUM(Net_Discount)- LAG(SUM(Net_Discount),1,0) OVER (ORDER BY Year,MONTH) AS Monthly_Change
FROM 
	Orders
WHERE 
	MONTH in (5,6,7,8,9,10,11,12)
GROUP BY 
	Year, 
	MONTH
--ORDER BY Year, MONTH
)
SELECT *, 
	SUM(Total_Sales) OVER (Partition BY Year ORDER BY MONTH) AS Rolling_Yearly_Sales
FROM 
	Year_Sales


--Category Sales/ Orders
SELECT 
	Category,
	COUNT(DISTINCT(Order_ID)) AS Num_Cat_Orders,
	SUM(Net_Discount) as Total_Cat_Sales,
	ROUND(AVG(Net_Discount),2) AS Avg_Cat_Sale
FROM 
	Orders
GROUP BY
	Category
ORDER BY
	 SUM(Net_Discount) DESC


--Best Selling Items
SELECT
	TOP 10
	SKU,
	Category,
	COUNT(DISTINCT(Order_ID)) AS Num_SKU_Orders,
	SUM(Net_Discount) as Total_SKU_Sales,
	ROUND(AVG(Net_Discount),2) AS Avg_SKU_Sale,
	ROUND(AVG(Net_Discount) - AVG([Production _Cost]),2) As Avg_Net_Profit,
	COUNT(DISTINCT(Order_ID)) * ROUND(AVG(Net_Discount) - AVG([Production _Cost]),2) AS Total_Profit
FROM 
	Orders
GROUP BY
	SKU,
	Category
ORDER BY
	COUNT(DISTINCT(Order_ID)) DESC



--CTE FOR Gender Percent Calc
WITH Gender_Percent AS
(
SELECT 
	Gender,
	COUNT(DISTINCT(Customer_ID)) AS Num_of_Customers 
FROM
	Customers
WHERE
	Gender IS NOT NULL
GROUP BY
	Gender
--ORDER BY
--	COUNT(DISTINCT(Customer_ID))
)

--Percent of Customer- Genders
SELECT *,
	CAST(ROUND(Num_of_Customers * 1.0/(SELECT SUM(Num_of_Customers) FROM Gender_Percent),4)*100 AS decimal(8,2)) AS Pct_Total
FROM Gender_Percent
Order BY
	Num_of_Customers DESC

--Number of Orders Per Age Group
SELECT 
	C.Age_Range,
	COUNT(O.Order_ID) AS Num_Orders
FROM
	Orders AS O
INNER JOIN
	Customers AS C
ON 
	O.Customer_ID = C.Customer_ID
GROUP BY
	C.Age_Range
ORDER BY
	COUNT(O.Order_ID) DESC



WITH Sales_By_Order AS
(
SELECT 
	O.Customer_ID,
	COUNT(Order_ID) as Num_Orders,
	AVG(O.Net_Discount) AS Avg_Sale
FROM Orders AS O
INNER JOIN
	Customers AS C
ON O.Customer_ID = C.Customer_ID
GROUP BY
	O.Customer_ID
)

SELECT
	Num_Orders,
	ROUND(AVG(Avg_Sale),2) AS Avg_Grouped_Order_Sale
FROM Sales_By_Order
GROUP BY
	Num_Orders
ORDER BY
	Num_Orders Desc


--CTE FOR Yearly Cost/ Profit Comparison
WITH Yearly_Profits AS
(
SELECT 
	Year,
	Total_Value,
	Discount,
	Net_Discount,
	[Production _Cost],
	Net_Discount - [Production _Cost] AS Net_Profit
FROM Orders
)
--Yearly Profit Comparison
SELECT 
	Year,
	ROUND(AVG(Total_Value),2) AS Avg_Total_Value,
	ROUND(AVG(Discount),2) AS Avg_Discount,
	ROUND(AVG(Net_Discount),2) AS Avg_Sale_Price,
	ROUND(AVG([Production _Cost]),2) AS Avg_Production_Cost,
	ROUND(AVG(Net_Profit),2) AS Avg_Net_Profit
FROM Yearly_Profits
GROUP BY
	Year