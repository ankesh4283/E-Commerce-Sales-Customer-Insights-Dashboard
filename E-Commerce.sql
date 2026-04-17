
--E-commerce Data Analysis (Olist Dataset)--

-- 1. Customers Table 
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

-- 2. Orders Table 
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATE,
    order_approved_at DATE,
    order_delivered_carrier_date DATE,
    order_delivered_customer_date DATE,
    order_estimated_delivery_date DATE
);

-- 3. Products Table 
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g DECIMAL,
    product_length_cm DECIMAL,
    product_height_cm DECIMAL,
    product_width_cm DECIMAL
);

-- 4. Order Items Table 
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATE,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 5. Order Payments Table 
CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10, 2)
);

-- 6. Product Category Translation Table (No changes needed)
CREATE TABLE product_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

--Data Cleaning

-- Convert a text column to a date
alter table orders 
alter column order_purchase_timestamp type date 

-- Ensure prices are numeric for calculations
alter table order_items 
alter column price type numeric(10,2) 
 
-- Remove leading spaces and fix casing
update customers 
set customer_city = lower(trim(customer_city));

--Update 
update order_payments
set payment_type = 'unknown'
where payment_type ='not_defined'


--Data
select * from customers
select * from orders
select * from products
select * from order_items
select count(distinct order_id)from order_payments
select * from product_category_translation



--1. Total Revenue
select round(sum(payment_value)/1000000,2) as revenue_in_million from order_payments;

--2. Total Orders
select count(order_id) as total_orders from orders;

--3. Total Customers
select count(distinct customer_unique_id) as total_customers from customers;

--4. Average Order Value (AOV)
select round(sum(payment_value)/count(distinct order_id),2)as avg_order_value from order_payments;

--5. What is the overall revenue trend over time.
select 
	to_char(o.order_purchase_timestamp,'Month')as months,
	sum(p.payment_value)
from order_payments as p
join orders as o 
on p.order_id=o.order_id
group by to_char(o.order_purchase_timestamp,'Month')
order by sum(p.payment_value) desc;

--6. Which  categories generate the highest revenue, and which are underperforming?
select 
	p.product_category_name_english,
	sum(pa.payment_value)
from products as pr
join order_items as o
on pr.product_id=o.product_id
join order_payments as pa
on o.order_id=pa.order_id
join product_category_translation as p
on pr.product_category_name = p.product_category_name
group by p.product_category_name_english
order by sum(pa.payment_value) desc ;

--7. What percentage of customers are repeat customers versus one-time buyers?
select 
count(case when order_count > 1 then 1 end)*100/count(*) || '%' as repeat_customers,
count(case when order_count = 1 then 1 end)*100/count(*) || '%' as one_time_customers
from (select 
		c.customer_unique_id,
		count(o.order_id) as order_count
	from customers as c
	join orders as o
	on c.customer_id=o.customer_id
	group by c.customer_unique_id) as customer

--8. What is the customer lifetime value (CLV) across customers?
select 
	c.customer_unique_id ,
	sum(p.payment_value)as lifetime_value 
from customers as c
join orders as o
on c.customer_id=o.customer_id
join order_payments as p 
on o.order_id=p.order_id
group by c.customer_unique_id
order by sum(p.payment_value) desc;

--9. What is the average order value (AOV), and how does it change over time?
select 
	to_char(o.order_purchase_timestamp,'Month')as months,
	round(sum(p.payment_value)/count(distinct o.order_id),2) as avg_order_value
from order_payments as p
join orders as o 
on p.order_id=o.order_id
group by to_char(o.order_purchase_timestamp,'Month')
order by round(sum(p.payment_value)/count(distinct o.order_id),2) desc;

--10. Which  states generate the highest revenue?
select 
	c.customer_state , 
	round(sum(payment_value)/1000000,2) as revenue_in_million 
from customers as c
join orders as o
on c.customer_id=o.customer_id
join order_payments as p 
on o.order_id=p.order_id
group by c.customer_state
order by round(sum(payment_value)/1000000,2) desc;

--11. What percentage of orders are delivered on time versus delayed?
select 
count(case when diff > 0 then 1 end)*100/count(order_id)|| '%'as late_delivery,
count(case when diff <= 0 then 1 end)*100/count(order_id)|| '%'as on_time_delivery from 
	(select  
		order_id,
		order_delivered_customer_date - order_estimated_delivery_date as diff
	from orders 
	where order_status = 'delivered'
    and order_delivered_customer_date is not null )as  delivery;
	
--12. What is the average delivery time (purchase to delivery)?
select 
	round(avg(order_delivered_customer_date - order_purchase_timestamp)) ||' Days' as avg_delivery_tie
	from orders ;
	 
--13. What is the most preferred payment method, and which contributes the most revenue?
select 
	payment_type , 
	count(order_id) as total_orders,
	sum(payment_value)as total_revenue 
from order_payments
group by payment_type 
order by sum(payment_value) desc ;

--14. Are delays more common in certain months or seasons?
select 
	to_char(order_purchase_timestamp , 'Month')as months,
	count(case when order_delivered_customer_date > order_estimated_delivery_date then 1 end) as delay
from orders 
group by to_char(order_purchase_timestamp , 'Month')
order by delay desc;

--15. Which product categories have the highest repeat purchase rate?
select
	product_category_name ,
	count(case when purchase > 1 then 1 end)*100
	/count(*) || ' %' as repeat_purchase
from (select  
		c.customer_unique_id ,
		p.product_category_name,
		count(distinct o.order_id)as purchase
	from customers as c
	join orders as o
	on c.customer_id = o.customer_id
	join order_items as i
	on o.order_id = i.order_id 
	join products as p 
	on i.product_id = p.product_id
	group by c.customer_unique_id , p.product_category_name) repeat_rate
group by product_category_name 
order by repeat_purchase desc
--END--