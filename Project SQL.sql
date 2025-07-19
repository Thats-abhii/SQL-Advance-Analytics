-- Analyize Sales Performance Over Time With Customers
USE Project
 
SELECT 
YEAR(order_date) AS Order_Years,
MONTH(order_date) AS Order_Month,
SUM(sales_amount) AS Total_Sales,
COUNT(customer_key) AS Total_Customers
FROM dbo.[gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

--Calculate the Total Sales Per Month and the running total of sales over time

SELECT 
Order_Date,
Total_Sales,
SUM(Total_Sales) OVER (ORDER BY Order_Date) AS Cummutative_Sales
FROM
	(
	SELECT 
	DATETRUNC(month, order_date) AS Order_Date, 
	SUM(sales_amount) AS Total_Sales
	FROM dbo.[gold.fact_sales]
	WHERE DATETRUNC(month , order_date)  IS NOT NULL
	GROUP BY DATETRUNC(month , order_date) 
	)t

--Analyze the Yearly performance of products by comparing each product sales to both 
--its Average Sales Performance and Previous Year Sales
 
 WITH CTE_A AS
(
	SELECT
	YEAR(S.order_date) AS Order_Year,
	P.product_name,
	SUM(S.sales_amount) AS Total_Sales 
	FROM dbo.[gold.fact_sales] AS S
	LEFT JOIN dbo.[gold.dim_products] AS P
	ON S.product_key = P.product_key
	WHERE YEAR(S.order_date) IS NOT NULL 
	GROUP BY P.product_name , 
	YEAR(S.order_date)
)
SELECT 
Order_Year,
product_name,
Total_Sales,
AVG(Total_Sales) OVER (PARTITION BY product_name) AS Avg_Sales,
Total_Sales -  AVG(Total_Sales) OVER (PARTITION BY product_name) AS Avg_Diff,
CASE 
	WHEN Total_Sales -  AVG(Total_Sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	WHEN Total_Sales -  AVG(Total_Sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	ELSE'Avg'
END AS Avg_Change,
LAG(Total_Sales,1,0) OVER (PARTITION BY product_name ORDER BY  Order_Year) AS Previous_Sales,
Total_Sales - LAG(Total_Sales,1,0) OVER (PARTITION BY product_name ORDER BY  Order_Year) AS Previous_Diff,
CASE 
	WHEN Total_Sales -   LAG(Total_Sales,1,0) OVER (PARTITION BY product_name ORDER BY  Order_Year) > 0 THEN 'Increasing'
	WHEN Total_Sales -   LAG(Total_Sales,1,0) OVER (PARTITION BY product_name ORDER BY  Order_Year) < 0 THEN 'Decreasing'
	ELSE 'No Change'
END AS Previous_Change
FROM CTE_A
ORDER BY 
product_name , Order_Year

--Which Categories Contribute the most to overall Sales

WITH CTE_Category AS 
(
SELECT
P.category ,
SUM(S.sales_amount) AS Total_Sales
FROM dbo.[gold.fact_sales] AS S
LEFT JOIN dbo.[gold.dim_products] AS P
ON S.product_key  = P.product_key
GROUP BY P.category
)
SELECT 
CTE_Category.category,
CTE_Category.Total_Sales,
SUM(Total_Sales) OVER () AS Overall_Sales,
CONCAT(ROUND((CAST(Total_Sales AS FLOAT)/ SUM(Total_Sales) OVER () ) * 100 , 2) , ' %' ) AS Percentage_Sales
FROM CTE_Category
ORDER BY CTE_Category.Total_Sales DESC

--Segment Products into Cost ranges and count how many products fall into each segment

WITH Product_Category AS(
SELECT
product_key ,
product_name ,
cost,
CASE 
	WHEN cost < 100 THEN 'Below 100'
	WHEN cost Between 100 AND 500 THEN '100-500'
	WHEN cost Between 500 AND 1000 THEN '500-1000'
	ELSE 'Above 1000'
END AS Check_Cost
FROM 
dbo.[gold.dim_products]
)
SELECT 
Check_Cost ,
COUNT(product_key) AS Total_Products
FROM Product_Category
GROUP BY Check_Cost
ORDER BY COUNT(product_key) ASC

--Group customers into three segments based on their spending behavior:
--VIP: at least 12 months of history and spending more than €5,000.
--Regular: at least 12 months of history but spending €5,000 or less.
--New: lifespan less than 12 months:
--Find the Total number of customer in the each group.

WITH Customer_Spending AS 
(
SELECT
S.customer_key ,
MIN(S.order_date) AS First_Order ,
MAX(S.order_date) AS Last_Order ,
SUM(S.sales_amount) AS Total_Sales
FROM dbo.[gold.fact_sales] AS S
LEFT JOIN dbo.[gold.dim_customers] AS P
ON P.customer_key = S.customer_key
GROUP BY 
S.customer_key 
),
CTE_2 AS
(
SELECT 
customer_key,
Total_Sales,
DATEDIFF(Month , First_Order , Last_Order) AS Lifespan
FROM
Customer_Spending
),
CTE_3 AS
(
SELECT 
customer_key ,
CASE 
WHEN Lifespan >=12 AND Total_Sales > 5000 THEN 'Vip'
WHEN Lifespan >=12 AND Total_Sales < 5000 THEN 'Regular'
ELSE 'New'
END AS Customer_Segments
FROM
CTE_2
)
SELECT Customer_Segments ,
COUNT(customer_key) AS Total_Customers
FROM CTE_3
GROUP BY Customer_Segments
ORDER BY COUNT(customer_key) DESC


