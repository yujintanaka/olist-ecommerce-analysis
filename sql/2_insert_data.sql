-- Typecasting and inserting data into the tables ensures that the data is in the correct format and adheres to the constraints defined in the table schema.

-- Truncate all tables
TRUNCATE TABLE customers, orders, order_items, products, sellers, geolocation, reviews, payments CASCADE;

-- Insert data into customers table
INSERT INTO customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT 
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS INTEGER),
    customer_city,
    customer_state
FROM raw_customers;

-- Insert data into orders table
INSERT INTO orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT 
    order_id,
    customer_id,
    order_status,
    CAST(order_purchase_timestamp AS TIMESTAMP),
    CAST(order_approved_at AS TIMESTAMP),
    CAST(order_delivered_carrier_date AS TIMESTAMP),
    CAST(order_delivered_customer_date AS TIMESTAMP),
    CAST(order_estimated_delivery_date AS TIMESTAMP)
FROM raw_orders;

-- Insert data into order_items table
INSERT INTO order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT 
    order_id,
    CAST(order_item_id AS INTEGER),
    product_id,
    seller_id,
    CAST(shipping_limit_date AS TIMESTAMP),
    CAST(price AS NUMERIC),
    CAST(freight_value AS NUMERIC)
FROM raw_order_items;

-- Insert data into products table
-- Note: we are fixing the typo in the product_name_length and product_description_length columns
INSERT INTO products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name),
    CAST(p.product_name_lenght AS INTEGER),
    CAST(p.product_description_lenght AS INTEGER),
    CAST(p.product_photos_qty AS INTEGER),
    CAST(p.product_weight_g AS INTEGER),
    CAST(p.product_length_cm AS INTEGER),
    CAST(p.product_height_cm AS INTEGER),
    CAST(p.product_width_cm AS INTEGER)
FROM raw_products p
LEFT JOIN raw_translation t ON p.product_category_name = t.product_category_name;

-- Insert data into sellers table
INSERT INTO sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT 
    seller_id,
    CAST(seller_zip_code_prefix AS INTEGER),
    seller_city,
    seller_state
FROM raw_sellers;

-- Insert data into geolocation table
-- Note: We are using PERCENTILE_CONT to get the median for latitude and longitude
-- and MODE() to get the most common city and state for each zip code prefix
INSERT INTO geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT 
    CAST(geolocation_zip_code_prefix AS INTEGER),
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(geolocation_lat AS NUMERIC)) AS geolocation_lat,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(geolocation_lng AS NUMERIC)) AS geolocation_lng,
    MODE() WITHIN GROUP (ORDER BY geolocation_city) AS geolocation_city,
    MODE() WITHIN GROUP (ORDER BY geolocation_state) AS geolocation_state
FROM raw_geolocation
GROUP BY geolocation_zip_code_prefix;

-- Insert data into reviews table
INSERT INTO reviews (
    review_id,
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp
)
SELECT 
    review_id,
    order_id,
    CAST(review_score AS INTEGER),
    CAST(review_creation_date AS TIMESTAMP),
    CAST(review_answer_timestamp AS TIMESTAMP)
FROM raw_order_reviews;

-- Insert data into payments table
INSERT INTO payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT 
    order_id,
    CAST(payment_sequential AS INTEGER),
    payment_type,
    CAST(payment_installments AS INTEGER),
    CAST(payment_value AS NUMERIC)
FROM raw_order_payments;


SELECT * FROM customers LIMIT 5;
SELECT * FROM orders LIMIT 5;
SELECT * FROM order_items LIMIT 5;
SELECT * FROM products LIMIT 5;
SELECT * FROM sellers LIMIT 5;
SELECT * FROM geolocation LIMIT 5;
SELECT * FROM reviews LIMIT 5;
SELECT * FROM payments LIMIT 5;