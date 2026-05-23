/* create customer table to import data */
CREATE TABLE customers
(customer_id TEXT,
customer_unique_id TEXT,
customer_zip_code_prefix TEXT,
customer_city TEXT,
customer_state TEXT);

/* check that data loaded */
SELECT *
FROM customers

/* create orders table to import data */
CREATE TABLE orders
(order_id TEXT,
customer_id	TEXT,
order_status TEXT,
order_purchase_timestamp TEXT,
order_approved_at TEXT,
order_delivered_carrier_date TEXT,
order_delivered_customer_date TEXT,
order_estimated_delivery_date TEXT);

/* check that data loaded */
SELECT *
FROM orders;

/* create order_items table for data import */
CREATE TABLE order_items
(order_id TEXT,
order_item_id TEXT,
product_id TEXT,
seller_id TEXT,
shipping_limit_date TEXT,
price TEXT,
freight_value TEXT
);

/* check that data loaded */
SELECT *
FROM order_items;

/* create table payments for data import */
CREATE TABLE payments
(order_id TEXT,
payment_sequential TEXT,
payment_type TEXT,
payment_installments TEXT,
payment_value TEXT
);

/* check that data loaded */
SELECT *
FROM payments;

/* create table products for data import */
CREATE TABLE products
(product_id TEXT,
product_category_name TEXT,
product_name_lenght TEXT,
product_description_lenght TEXT,
product_photos_qty TEXT,
product_weight_g TEXT,
product_length_cm TEXT,
product_height_cm TEXT,
product_width_cm TEXT
);

/* check that data loaded */
SELECT *
FROM products

/* change data types from TEXT to correct data type */

/* oder_items table data */
ALTER TABLE order_items
ALTER COLUMN price TYPE NUMERIC USING price::numeric,
ALTER COLUMN freight_value TYPE NUMERIC USING freight_value::numeric,
ALTER COLUMN shipping_limit_date TYPE TIMESTAMP USING shipping_limit_date::timestamp,
ALTER COLUMN order_item_id TYPE INTEGER USING order_item_id::integer;

/* orders table data*/
ALTER TABLE orders
ALTER COLUMN order_purchase_timestamp TYPE TIMESTAMP USING order_purchase_timestamp::timestamp,
ALTER COLUMN order_approved_at TYPE TIMESTAMP USING order_approved_at::timestamp,
ALTER COLUMN order_delivered_carrier_date TYPE TIMESTAMP USING order_delivered_carrier_date::timestamp,
ALTER COLUMN order_delivered_customer_date TYPE TIMESTAMP USING order_delivered_customer_date::timestamp,
ALTER COLUMN order_estimated_delivery_date TYPE TIMESTAMP USING order_estimated_delivery_date::timestamp;

/* payments table data */
ALTER TABLE payments
ALTER COLUMN payment_value TYPE NUMERIC USING payment_value::numeric,
ALTER COLUMN payment_installments TYPE INTEGER USING payment_installments::integer,
ALTER COLUMN payment_sequential TYPE INTEGER USING payment_sequential::integer;

/* products table data */
ALTER TABLE products
ALTER COLUMN product_weight_g TYPE INTEGER USING product_weight_g::integer,
ALTER COLUMN product_length_cm TYPE INTEGER USING product_length_cm::integer,
ALTER COLUMN product_height_cm TYPE INTEGER USING product_height_cm::integer,
ALTER COLUMN product_width_cm TYPE INTEGER USING product_width_cm::integer,
ALTER COLUMN product_name_lenght TYPE INTEGER USING product_name_lenght::integer,
ALTER COLUMN product_description_lenght TYPE INTEGER USING product_description_lenght::integer,
ALTER COLUMN product_photos_qty TYPE INTEGER USING product_photos_qty::integer;

/** REVENUE AND GROWTH **/

/* 1. What is the monthly revenue trend? */
SELECT 
	DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
	ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;

/* 2. What is the month-over-month growth rate? */
WITH monthly_revenue AS (
	SELECT
		DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
		SUM(p.payment_value) AS revenue
	FROM orders o
	JOIN payments p ON o.order_id = p.order_id
	GROUP BY MONTH
)
SELECT
	month,
	revenue,
	LAG(revenue) OVER (ORDER BY MONTH) AS previous_month,
	ROUND(
		(revenue - LAG(revenue) OVER (ORDER BY month))
		/LAG(revenue) OVER (ORDER BY month)*100, 2
		) AS growth_rate_pect
FROM monthly_revenue;

/* 3. Which months show seasonality patterns? */
SELECT
	EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month_number,
	ROUND(AVG(p.payment_value), 2) AS avg_order_value,
	ROUND(SUM(p.payment_value), 2) AS total_revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY month_number
ORDER BY month_number;

/** CUSTOMER BEHAVIOR **/

/* 1. What is the repeat purchase rate? */
WITH customer_orders AS (
	SELECT
		customer_id,
		COUNT(order_id) AS order_count
	FROM orders
	GROUP BY customer_id
)
SELECT
	ROUND(
		COUNT(*) FILTER (WHERE order_count > 1) * 1.0
		/COUNT(*), 3
	) AS repeat_purchase_rate
FROM customer_orders;

/* 2. What is average order value? */
SELECT
	ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
	SELECT
		o.order_id,
		SUM(p.payment_value) AS order_total
	FROM orders o
	JOIN payments p ON o.order_id = p.order_id
	GROUP BY o.order_id
)
/* 3. Who are the top 10% of customers by revenue? */
WITH customer_revenue AS (
	SELECT
		c.customer_id,
		SUM(p.payment_value) AS total_spent
	FROM customers c
	JOIN ordes o ON c.customer_id = o.customer_id
	JOIN payments p ON o.order_id = p.order_id
),
ranked AS (
	SELECT *,
		NTILE(10) OVER (ORDER BY total_spent DESC) AS decile
	FROM customer_revenue
)
SELECT *
FROM Ranked
WHERE decile = 1
ORDER BY total_spent DESC;

/** PRODUCT AND CATEGORY INSIGHTS **/

/* 1. Which product categories generate the most revenue? */
SELECT
	pr.product_category_name,
	ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products pr ON oi.product_id = pr.product_id
GROUP BY pr.product_category_name
ORDER BY revenue DESC
LIMIT 10;

/* 2. Which categories have the highest order volume but low revenue? */
SELECT
	pr.product_category_name,
	COUNT(oi.order_id) AS order_volume,
	ROUND(SUM(p.payment_value), 2) AS revenue,
	ROUND(AVG(p.payment_value), 2) AS avg_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products pr ON oi.product_id = pr.product_id
GROUP BY pr.product_category_name
ORDER BY order_volume DESC, avg_value ASC;

/* 3. Are high-rated products actually generating more revenue? */

/** GEOGRAPHIC INSIGHTS **/

/* 1. Which states generate the most revenue? */
SELECT
	c.customer_state,
	ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY revenue DESC;

/* 2. Which regions have the highest AOV? */
SELECT
	c.customer_state,
	ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
	SELECT
		o.order_id,
		o.customer_id,
		SUM(p.payment_value) AS order_total
	FROM orders o
	JOIN payments p ON o.order_id = p.order_id
	GROUP BY o.order_id, o.customer_id
) sub
JOIN customers c ON sub.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY avg_order_value DESC;

/** RETENTION AND COHORTS **/

/* 1. What is the customer retention rate by cohort? */

/* 2. How long do customers stay active? */