-- Verify all data is loaded
SELECT * FROM raw_customers LIMIT 5;
SELECT * FROM raw_geolocation LIMIT 5;
SELECT * FROM raw_order_items LIMIT 5;
SELECT * FROM raw_order_payments LIMIT 5;
SELECT * FROM raw_order_reviews LIMIT 5;
SELECT * FROM raw_orders LIMIT 5;
SELECT * FROM raw_products LIMIT 5;
SELECT * FROM raw_sellers LIMIT 5;
SELECT * FROM raw_translation LIMIT 5;

INSERT INTO raw_translation
VALUES 
('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparators'),
('pc_gamer', 'pc_gamer');

SELECT * FROM raw_translation;

-- Check for duplicate primary keys in each table
-- Customers table
SELECT customer_id, COUNT(*) as count
FROM raw_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Orders table
SELECT order_id, COUNT(*) as count
FROM raw_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Order items table (composite primary key)
SELECT order_id, order_item_id, COUNT(*) as count
FROM raw_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Products table
SELECT product_id, COUNT(*) as count
FROM raw_products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Sellers table
SELECT seller_id, COUNT(*) as count
FROM raw_sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Reviews table
SELECT review_id, COUNT(*) as count
FROM raw_order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;


-- Since reviews table has multiple with same review_id, we will see what kind of data is duplicated

WITH duplicate_reviews AS (
    SELECT review_id
    FROM raw_order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
SELECT r.*
FROM raw_order_reviews r
INNER JOIN duplicate_reviews d ON r.review_id = d.review_id
ORDER BY r.review_id, r.review_creation_date;

-- It seems that single reviews are applied to multiple orders
-- We have removed primary key designation from review_id in the reviews table


-- Why do we have customer_id, and unique_customer_id in the customers table?
-- customer_id is also in the orders table

-- Check if one customer_unique_id maps to multiple customer_ids
SELECT 
    customer_unique_id,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
LIMIT 100;
-- Yes, one customer_unique_id maps to multiple customer_ids

-- Check overall counts
SELECT 
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_unique_ids
FROM customers;

--99441 customer_ids and 96096 customer_unique_ids

-- Look at a sample of matching pairs
SELECT 
    customer_id, 
    customer_unique_id
FROM customers
LIMIT 20;
-- customer_id and customer_unique

-- If they have the same unique_id, do they have the same zip code?

SELECT
    customer_id, 
    customer_unique_id,
    customer_zip_code_prefix
FROM customers
WHERE customer_unique_id IN (
    SELECT customer_unique_id
    FROM customers
    GROUP BY customer_unique_id
    HAVING COUNT(DISTINCT customer_id) > 1
)
ORDER BY customer_unique_id
LIMIT 20;

-- Conclusion: customer_unique_id points a single customer.
-- A single customer can have multiple customer_ids
-- Then why not use order_id instead?

-- Check if there are duplicate customer_id in the orders table
SELECT customer_id, COUNT(*) as count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Every customer_id in the orders table is unique
-- Check if there are multiple order_id for a single customer_id
SELECT customer_id, COUNT(DISTINCT order_id) as count
FROM orders
GROUP BY customer_id
HAVING COUNT(DISTINCT order_id) > 1
LIMIT 10;
-- one order_id is associate with 1 customer_id


-- Since Geolocation table is accessed only by the zip code, we won't need multiple entries for the same zip code
-- Since it has a million rows, we can assume it is from a different data source.
-- We will consolidate the geolocation table to have a single entry for each zip code



