USE [E-Commerce]

--DAwSQL Session -8 

--E-Commerce Project Solution



--1. Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

SELECT A.*, B.Order_Date, B.Order_Priority, 
       C.Customer_Name, C.Customer_Segment, C.Province, C.Region,
	   D.Order_ID, D.Ship_Date, D.Ship_Mode,
	   E.Product_Category, E.Product_Sub_Category
	   INTO combined_table
FROM market_fact A
INNER JOIN   orders_dimen B   ON A.Ord_id  = B.Ord_id
INNER JOIN   cust_dimen  C    ON A.Cust_id = C.Cust_id
INNER JOIN	 shipping_dimen D ON A.Ship_id = D.Ship_id
INNER JOIN	 prod_dimen     E ON A.Prod_id = E.Prod_id;

SELECT TOP 5 *
FROM combined_table




--///////////////////////


--2. Find the top 3 customers who have the maximum count of orders.

select Top 3 Cust_id, Customer_Name, count(*) maximum_order
from combined_table
group by Cust_id, Customer_Name
order by 3 DESC

--/////////////////////////////////



--3.Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.
--Use "ALTER TABLE", "UPDATE" etc.

ALTER TABLE combined_table 
ADD DaysTakenForDelivery SMALLINT


UPDATE combined_table
SET DaysTakenForDelivery = DATEDIFF(day, Order_date, Ship_date)
from combined_table


SELECT TOP 5 *
FROM combined_table

--////////////////////////////////////


--4. Find the customer whose order took the maximum time to get delivered.
--Use "MAX" or "TOP"


SELECT TOP 1 Customer_Name, Ord_id, DaysTakenForDelivery
FROM combined_table
ORDER BY 3 DESC 

--////////////////////////////////



--5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
--You can use date functions and subqueries


SELECT MONTH(Order_Date) Month_Year, COUNT(Cust_id) Total_Custmr
from combined_table
where YEAR(Order_Date)=2011
GROUP BY month(Order_Date)
ORDER BY month(Order_Date) ASC


--////////////////////////////////////////////


--6. write a query to return for each user acording to the time elapsed between the first purchasing and the third purchasing, 
--in ascending order by Customer ID
--Use "MIN" with Window Functions


WITH Tbl1 
AS
(
SELECT Cust_id,
       MAX(CASE WHEN ord_nmbr = 1 THEN A.Order_Date END) AS Order_Date1,
       MAX(CASE WHEN ord_nmbr = 3 THEN A.Order_Date END) AS Order_Date3,
       COUNT(DISTINCT A.Ord_id) AS TotalNumberOfOrders   
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY Cust_id ORDER BY Order_Date) AS ord_nmbr
      FROM combined_table 
     ) A
GROUP BY Cust_id
)
SELECT CONVERT(VARCHAR(5),
       DATEDIFF(s, Order_Date1, Order_Date3) / 3600)+ ':' + CONVERT(VARCHAR(5),
       DATEDIFF(s, Order_Date1, Order_Date3) %3600 / 60)+ ':' + CONVERT(VARCHAR(5),
	   DATEDIFF(s, Order_Date1, Order_Date3) %60) Past_Time
FROM Tbl1 WHERE Order_Date3 is Not null



--//////////////////////////////////////

--7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by all customers.
--Use CASE Expression, CTE, CAST and/or Aggregate Functions

WITH Tbl1 
AS 
(
SELECT * 
FROM combined_table
WHERE Cust_id in 
     (
	  SELECT Cust_id
	  FROM combined_table
	  WHERE Prod_id in ('Prod_11','Prod_14')
	  GROUP BY Cust_id
	  HAVING COUNT(DISTINCT Prod_id) = 2
     )
),
Tbl2
AS
(
    SELECT DISTINCT prod_id,
			SUM(Order_Quantity * Product_Base_Margin) 
			OVER(PARTITION BY Prod_id) total_prod,
			SUM(Order_Quantity *  Product_Base_Margin)
			OVER() total,
			SUM(Order_Quantity * Product_Base_Margin) 
			OVER(PARTITION BY Prod_id) / SUM(Order_Quantity*Product_Base_Margin) OVER() Ratio
	FROM combined_table
)

SELECT * FROM Tbl2 ORDER BY Prod_id


--/////////////////



--CUSTOMER SEGMENTATION



--1. Create a view that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
--Use such date functions. Don't forget to call up columns you might need later.

CREATE VIEW logs
AS
SELECT Cust_id, MONTH(Order_Date) [MONTH], YEAR(Order_Date) [YEAR]
FROM combined_table

SELECT *
FROM logs

--//////////////////////////////////



  --2.Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning  business)
--Don't forget to call up columns you might need later.

CREATE VIEW visits
AS
SELECT MONTH(Order_Date) [MONTH], COUNT(Cust_id) total_Cust
FROM combined_table
GROUP BY MONTH(Order_Date)

SELECT *
FROM visits

--//////////////////////////////////


--3. For each visit of customers, create the next month of the visit as a separate column.
--You can order the months using "DENSE_RANK" function.
--then create a new column for each month showing the next month using the order you have made above. (use "LEAD" function.)
--Don't forget to call up columns you might need later.

SELECT Cust_id,
			  MONTH(Order_Date) [MONTH],
	          COUNT(Cust_id) OVER(PARTITION BY Cust_id          ORDER BY MONTH(Order_Date) ASC)  Visit_num,
	          LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY MONTH(Order_Date) ASC)  Next_Month,
	          LEAD(COUNT(Cust_id)) OVER(PARTITION BY Cust_id    ORDER BY MONTH(Order_Date) ASC) Next_Month_Visit,
	          DENSE_RANK() OVER(PARTITION BY Cust_id            ORDER BY MONTH(Order_Date) ASC)  With_Dense_Rank
FROM combined_table
GROUP BY Cust_id, MONTH(Order_Date)


--/////////////////////////////////



--4. Calculate monthly time gap between two consecutive visits by each customer.
--Don't forget to call up columns you might need later.


WITH Tbl1 
AS
(
SELECT Cust_id,
			  MONTH(Order_Date) [MONTH],
			  LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY MONTH(Order_Date) ASC) Next_Month
FROM combined_table
GROUP BY Cust_id, MONTH(Order_Date)
)
select Cust_id, Next_Month - [MONTH] Time_gap
from Tbl1




--///////////////////////////////////


--5.Categorise customers using average time gaps. Choose the most fitted labeling model for you.
--For example: 
--Labeled as “churn” if the customer hasn't made another purchase for the months since they made their first purchase.
--Labeled as “regular” if the customer has made a purchase every month.
--Etc.
	

WITH Tbl1 
AS
(
SELECT Cust_id,
			  MONTH(Order_Date) [MONTH],
			  LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY MONTH(Order_Date) ASC) Next_Month
FROM combined_table
GROUP BY Cust_id, MONTH(Order_Date)
),
Tbl2 
AS
(
SELECT Cust_id, Next_Month - [MONTH] Time_gap 
FROM Tbl1
)
select Cust_id,avg(Time_gap) Avg_Time_gap,
    CASE
        WHEN avg(Time_gap)=1 THEN 'Loyal'
        WHEN avg(Time_gap)=2 THEN 'Discount'
        WHEN avg(Time_gap)=3 THEN 'Impulse'
        WHEN avg(Time_gap)=4 THEN 'Need-based'
        WHEN avg(Time_gap)>4 THEN 'Wandering'
        ELSE
        'One Time Order'
    END AS Categorise_Customers
    from Tbl2
GROUP by Cust_id





--/////////////////////////////////////




--MONTH-WISE RETENTÝON RATE


--Find month-by-month customer retention rate  since the start of the business.


--1. Find the number of customers retained month-wise. (You can use time gaps)
--Use Time Gaps

WITH Tbl1 AS
(
SELECT DISTINCT Cust_id, 
				MONTH(Order_Date) First_Month, 
				YEAR(Order_Date) First_Year,
				LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Cust_id, YEAR(Order_Date) ASC, MONTH(Order_Date)) Second_Month,
				LEAD(YEAR(Order_Date))  OVER(PARTITION BY Cust_id ORDER BY Cust_id, YEAR(Order_Date) ASC, MONTH(Order_Date)) Second_Year
FROM combined_table
GROUP BY Cust_id,MONTH(Order_Date),YEAR(Order_Date)

),
Tbl2 
AS
(
    SELECT *,
    CASE
        WHEN First_Year = Second_Year and Second_Month - First_Month = 1 THEN 1
        ELSE 0
    END AS Frequency
    FROM Tbl1
)
SELECT SUM(Frequency) Freq_cust , COUNT(Cust_id) total_cust
FROM Tbl2



--//////////////////////


--2. Calculate the month-wise retention rate.

--Basic formula: o	Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month

--It is easier to divide the operations into parts rather than in a single ad-hoc query. It is recommended to use View. 
--You can also use CTE or Subquery if you want.

--You should pay attention to the join type and join columns between your views or tables.


WITH Tbl1 AS
(
SELECT DISTINCT Cust_id, 
				MONTH(Order_Date) First_Month, 
				YEAR(Order_Date) First_Year,
				LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Cust_id, YEAR(Order_Date) ASC, MONTH(Order_Date)) Second_Month,
				LEAD(YEAR(Order_Date))  OVER(PARTITION BY Cust_id ORDER BY Cust_id, YEAR(Order_Date) ASC, MONTH(Order_Date)) Second_Year
FROM combined_table
GROUP BY Cust_id,MONTH(Order_Date),YEAR(Order_Date)

),
Tbl2 
AS
(
    SELECT *,
    CASE
        WHEN First_Year = Second_Year and Second_Month - First_Month = 1 THEN 1
        ELSE 0
    END AS Frequency
    FROM Tbl1
)
SELECT SUM(Frequency) Freq_cust , COUNT(Cust_id) total_cust
FROM Tbl2

SELECT DISTINCT Cust_id, MONTH(Order_Date) [Month], YEAR(Order_Date) [Year] 
FROM combined_table 
WHERE Cust_id = 'Cust_1001'
ORDER BY YEAR(Order_Date) ASC, MONTH(Order_Date) ASC




---///////////////////////////////////
--Good luck!