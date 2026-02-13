-- Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region

SELECT 
    market
FROM
    dim_customer
WHERE
    customer LIKE '%atliq exclusive%'
        AND region = 'apac';
        
 -- What is the percentage of unique product increase in 2021 vs. 2020?

WITH 
	cte2020 AS
	(
		SELECT 
			COUNT(DISTINCT product_code) as 'product_count_2020'
		FROM
			fact_sales_monthly
		WHERE
			GET_FISCAL_YEAR(date) = 2020
	)
	,
	cte2021 AS
	(
		SELECT 
			COUNT(DISTINCT product_code) as 'product_count_2021'
		FROM
			fact_sales_monthly
		WHERE
			GET_FISCAL_YEAR(date) = 2021
	)
SELECT 
    product_count_2020 as 'unique_product_2020',
    product_count_2021 as 'unique_product_2021',
    ROUND(((cte2021.product_count_2021 - cte2020.product_count_2020) * 100) / cte2020.product_count_2020,2) AS 'percentage_chg'
FROM
    cte2020,cte2021;
    
-- Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.

SELECT 
    segment, COUNT(DISTINCT product_code) AS 'product_count'
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- Which segment had the most increase in unique products in 2021 vs 2020?

WITH 
	cte2020 AS
	(
		SELECT 
			p.segment,
            COUNT(DISTINCT s.product_code) AS 'product_count_2020'
		FROM
			fact_sales_monthly s JOIN dim_product p ON s.product_code = p.product_code
		WHERE
			GET_FISCAL_YEAR(s.date) = 2020
		GROUP BY p.segment
	)
	,
	cte2021 AS
	(
		SELECT 
			p.segment,
			COUNT(DISTINCT s.product_code) AS 'product_count_2021'
		FROM
			fact_sales_monthly s JOIN dim_product p ON s.product_code = p.product_code
		WHERE
			GET_FISCAL_YEAR(s.date) = 2021
		GROUP BY p.segment
	)
SELECT 
    cte2020.segment,
    cte2021.product_count_2021,
	cte2020.product_count_2020,
    cte2021.product_count_2021 - cte2020.product_count_2020 AS 'difference'
FROM
    cte2020 JOIN cte2021 on cte2020.segment = cte2021.segment
GROUP BY cte2020.segment
ORDER BY difference DESC;

-- Get the products that have the highest and lowest manufacturing costs.

with cte as 
(
	SELECT 
		p.product_code,
		p.product,
		SUM(mc.manufacturing_cost) AS 'manufacturing_cost'
	FROM
		fact_manufacturing_cost mc
			JOIN
		dim_product p ON mc.product_code = p.product_code
	GROUP BY p.product_code , p.product
	ORDER BY manufacturing_cost DESC
)
SELECT product_code, product, ROUND(manufacturing_cost,2) as "total_manufacturing_cost"
FROM cte
WHERE manufacturing_cost = 
												(SELECT MIN(manufacturing_cost) 
                                                FROM cte) 
			 OR 
			 manufacturing_cost = (SELECT MAX(manufacturing_cost) 
												FROM cte);
            
-- Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.

SELECT 
    c.customer_code,
    c.customer,
    ROUND(AVG(pre.pre_invoice_discount_pct), 4) AS 'average_discount_percentage'
FROM
    dim_customer c
        JOIN
    fact_pre_invoice_deductions pre ON c.customer_code = pre.customer_code
WHERE
    pre.fiscal_year = 2021
        AND c.market = 'india'
GROUP BY c.customer_code , c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions.

SELECT 
    MONTH(s.date) AS 'month',
    GET_FISCAL_YEAR(s.date) AS 'year',
    ROUND(SUM(g.gross_price * s.sold_quantity), 2) AS 'gross_sales_amount'
FROM
    fact_gross_price g
        JOIN
    fact_sales_monthly s ON g.product_code = s.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
        JOIN
    dim_customer c ON s.customer_code = c.customer_code
WHERE
    c.customer = 'Atliq Exclusive'
GROUP BY year , MONTH(date)
ORDER BY year , MONTH(date);

-- In which quarter of 2020, got the maximum total_sold_quantity?

SELECT 
    GET_FISCAL_QUARTER(date) AS 'quarter',
    SUM(sold_quantity) AS 'total_sold_quantity'
FROM
    fact_sales_monthly
WHERE
    GET_FISCAL_YEAR(date) = 2020
GROUP BY GET_FISCAL_QUARTER(date)
ORDER BY total_sold_quantity DESC
LIMIT 1;

-- Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?

WITH cte AS
(
	SELECT 
		c.channel,
		ROUND((SUM(g.gross_price * s.sold_quantity) / 1000000),2) AS 'gross_sales_mln'
	FROM
		fact_gross_price g
			JOIN
		fact_sales_monthly s ON g.product_code = s.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
			JOIN
		dim_customer c ON s.customer_code = c.customer_code
	WHERE
		g.fiscal_year = 2021
	GROUP BY c.channel
	ORDER BY gross_sales_mln DESC
)
SELECT channel,
			gross_sales_mln,
            ROUND((gross_sales_mln * 100)/SUM(gross_sales_mln) OVER(),2) AS 'percentage'
FROM cte
GROUP BY channel
ORDER BY gross_sales_mln DESC
LIMIT 1;

-- Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?

with cte2 as
(	
	with cte1 as
	(
		SELECT 
			p.division,
			p.product_code,
			p.product,
			SUM(s.sold_quantity) AS 'total_sold_quantity'
		FROM
			fact_sales_monthly s
				JOIN
			dim_product p ON s.product_code = p.product_code
		WHERE get_fiscal_year(s.date) = 2021
		GROUP BY p.division, p.product_code, p.product
		ORDER BY total_sold_quantity DESC
	)
	SELECT *,
				DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS 'rank_order'
	FROM cte1
)
SELECT * FROM cte2 
WHERE rank_order<=3;
