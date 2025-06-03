-- 1. Granular Orders with Purchasing Behavior and Customer Satisfaction
-- View for Calculating Costs associated to bad delivery, dollar value of 1 day
WITH order_sequence AS (SELECT
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id 
        ORDER BY o.order_purchase_timestamp
    ) AS nth_order
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
GROUP BY order_id, c.customer_unique_id, o.order_purchase_timestamp
),
current_order AS (SELECT
-- each order is tied to 1 shipment, but can have multiple products
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_status,
    AVG(r.review_score) AS average_review_score,
    -- aggregates over multiple payment methods
    SUM(p.payment_value) AS total_payment_value,
    SUM(p.payment_value) - SUM(oi.freight_value) AS payment_less_shipping,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - order_estimated_delivery_date)) AS delay_time,
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '-5 days' THEN 'Very Early'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '1 days' THEN 'ontime'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '10 days' THEN 'Late'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) >= INTERVAL '10 days' THEN 'Very Late'
        ELSE 'Not Delivered'
    END AS delivery_performance
FROM orders o
LEFT JOIN reviews r ON o.order_id = r.order_id
LEFT JOIN payments p ON o.order_id = p.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id
ORDER BY order_purchase_timestamp
)
SELECT
    co.order_id,
    c.customer_unique_id,
    co.order_purchase_timestamp,
    co.order_status,
    co.average_review_score,
    co.total_payment_value,
    co.payment_less_shipping,
    co.delivery_time,
    co.delay_time,
    co.delivery_performance,
    os.nth_order
FROM current_order co
LEFT JOIN order_sequence os ON co.order_id = os.order_id
LEFT JOIN customers c ON co.customer_id = c.customer_id

-- Want the review score and the effect of purchase frequency, so it should be
-- displayed review score + time until next purchase
-- For each product, review score for each review timestamp.
-- For each order, review score at time of purchase
-- Want in the end a table, for each review score the average time to next purchase.
-- Need to take the average review score between two purchases
-- Want data point only for re-purchases

WITH times AS (SELECT
COUNT(oi.product_id) as times_order,
AVG(r.review_score) as review_score
from order_items oi
LEFT JOIN reviews r ON r.order_id = oi.order_id
GROUP BY product_id
)
SELECT times_order, COUNT(*),
AVG(review_score)
FROM times
GROUP BY times_order
ORDER BY times_order
--review scores are extremely flat across all purchase frequencies.
-- This likely means the review scores are not displayed,
-- or it is not a big factor for people making the purchases.
-- we must look towards individual customer behavior?
-- perhaps review scores do not translate to extra revenue? or is there a threshold at which
-- bad reviews will kill a product?

--Next query: per products in each review group, 0-1, 1-2, 2-3, 3-4, 4-5, what is the average revenue?
-- total revenue / number of products in the the review group
-- need first to get product, average review, total revenue

WITH per_product_score_revenue AS (SELECT
COUNT(oi.order_id) as num_orders,
oi.product_id,
CASE
    WHEN AVG(r.review_score) IS NULL THEN 'null'
    WHEN AVG(r.review_score) <1 THEN '0-1'
    WHEN AVG(r.review_score) <2 THEN '1-2'
    WHEN AVG(r.review_score) <3 THEN '2-3'
    WHEN AVG(r.review_score) <4 THEN '3-4'
    WHEN AVG(r.review_score) <=5 THEN '4-5'
    ELSE 'other'
END AS review_bucket,
SUM(p.payment_value) as total_revenue
FROM order_items oi
LEFT JOIN payments p ON oi.order_id = p.order_id
LEFT JOIN reviews r ON oi.order_id = r.order_id
GROUP BY oi.product_id
HAVING COUNT(r.review_id) > 10
)
SELECT
ppsr.review_bucket,
SUM(ppsr.num_orders) as number_orders,
COUNT(ppsr.product_id) as number_products,
AVG(ppsr.total_revenue) as avg_revenue
FROM per_product_score_revenue ppsr
GROUP BY ppsr.review_bucket
ORDER BY review_bucket
-- This gives us the nonsensical result that
--lower review scores give us more revenue.
-- possible explanation
-- Heavier items cost more, they take longer to deliver,
-- longer delivery = lower review score.

-- As we investigated, lower review != lower purchases

-- To get the pure effect of customer satisfaction on future sales
-- can only be found using customer data over time, which we do not have.

-- as a summary -- delivery definitely has an effect on reviews
-- However, we cannot quanity the effect it has on future sales or customer behavior
-- due to the limited timescope of the data,
-- as well as reviews most likely not swaying other customers.





-- View for Identifying BAD sellers
-- distance, weight, freight cost, 
SELECT
o.order_id AS order_id,
oi.seller_id AS seller_id,
s.seller_state,
s.seller_city,
o.order_status AS order_status,
o.order_purchase_timestamp AS purchase_date,
o.order_approved_at AS approved_date,
o.order_delivered_carrier_date AS carrier_date,
o.order_delivered_customer_date AS customer_date,
o.order_estimated_delivery_date AS estimate_date,
oi.shipping_limit_date AS shipping_limit_date,
oi.freight_value AS freight_value,
p.product_weight_g,
oi.price AS price,
(
    6371 * -- Earth's radius in kilometers
    2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(gs.geolocation_lat - gc.geolocation_lat) / 2), 2) +
            COS(RADIANS(gc.geolocation_lat)) * 
            COS(RADIANS(gs.geolocation_lat)) * 
            POWER(SIN(RADIANS(gs.geolocation_lng - gc.geolocation_lng) / 2), 2)
        )
    )
) AS distance,
p.product_category_name as category,
EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
EXTRACT(DAY FROM (o.order_delivered_customer_date - order_estimated_delivery_date)) AS delivery_performance,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN geolocation gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix
LEFT JOIN geolocation gs ON s.seller_zip_code_prefix = gs.geolocation_zip_code_prefix



-- How can we improve? potential solutions and the impact
-- Potential solutions: If there are bad sellers, see where they are erring,
-- perhaps we can tell them to change carriers.

-- We can give an estimate a few days later than recommended.
-- However, we need to investigate the impact this will have on revenue
 -- Given the same weight, distance and price, how does purchase frequency change based on the given estimate?
 -- The best solution would be just to AB test and get data. This will not require long-term data.


-- Since we did not quantify the benefit of faster delivery, we cannot make recommendations 





-- Freight Class view

SELECT
p.product_weight_g,
p.product_length_cm,
p.product_height_cm,
p.product_width_cm,
(
    6371 * -- Earth's radius in kilometers
    2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(gs.geolocation_lat - gc.geolocation_lat) / 2), 2) +
            COS(RADIANS(gc.geolocation_lat)) * 
            COS(RADIANS(gs.geolocation_lat)) * 
            POWER(SIN(RADIANS(gs.geolocation_lng - gc.geolocation_lng) / 2), 2)
        )
    )
) AS distance,
oi.freight_value AS freight_value,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN geolocation gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix
LEFT JOIN geolocation gs ON s.seller_zip_code_prefix = gs.geolocation_zip_code_prefix;



--- Create view for machine learning to check high risk deliveries.
-- MACHINE LEARNING QUERY

SELECT
c.customer_unique_id,
EXTRACT(DAY FROM (o.order_delivered_customer_date - order_estimated_delivery_date)) AS delay_time,
(SELECT COUNT(DISTINCT seller_id) 
 FROM order_items oi_sub 
 WHERE oi_sub.order_id = o.order_id) AS unique_seller_count,
EXTRACT(DAY FROM (oi.shipping_limit_date - o.order_purchase_timestamp)) AS delivery_time_buffer,
(SELECT COUNT(DISTINCT product_id) 
 FROM order_items oi_sub 
 WHERE oi_sub.order_id = o.order_id) AS product_count,
(SELECT SUM(p.product_weight_g) 
 FROM order_items oi_sub 
 LEFT JOIN products p ON oi_sub.product_id = p.product_id 
 WHERE oi_sub.order_id = o.order_id) AS total_order_weight,
s.seller_state,
c.customer_state,
CONCAT(s.seller_state, c.customer_state) AS route,
EXTRACT(DAY FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp)) AS estimate_length,
oi.freight_value AS freight_value,
p.product_weight_g,
oi.price AS price,
(
    6371 * -- Earth's radius in kilometers
    2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(gs.geolocation_lat - gc.geolocation_lat) / 2), 2) +
            COS(RADIANS(gc.geolocation_lat)) * 
            COS(RADIANS(gs.geolocation_lat)) * 
            POWER(SIN(RADIANS(gs.geolocation_lng - gc.geolocation_lng) / 2), 2)
        )
    )
) AS distance,
p.product_category_name as category,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late,
CASE
    WHEN c.customer_state = s.seller_state THEN 1
    ELSE 0
END AS same_state,
CASE
    WHEN c.customer_city = s.seller_city THEN 1
    ELSE 0
END AS same_city
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN geolocation gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix
LEFT JOIN geolocation gs ON s.seller_zip_code_prefix = gs.geolocation_zip_code_prefix
WHERE order_status = 'delivered'
    AND order_estimated_delivery_date IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL



--- get the rural or not rural for each unique customer ID
SELECT
c.customer_unique_id,
gc.geolocation_lat AS latitude,
gc.geolocation_lng AS longitude
FROM customers c
LEFT JOIN geolocation gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix




-- Seller Based Diagnosis - Why are some sellers worse than others?
-- We will use Machine learning

-- Number of sales
-- most frequent month of sales
-- seller location
-- average product weight
-- number of categories sold
-- late delivery rate
-- average freight cost
-- average price of items sold
-- multiple sellers


WITH multiple_seller_orders AS (SELECT
order_id,
COUNT(DISTINCT seller_id) AS num_sellers
FROM order_items
GROUP BY order_id
)
SELECT
mso.num_sellers,
COUNT(*),
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM
orders o
LEFT JOIN multiple_seller_orders mso ON o.order_id = mso.order_id
GROUP BY num_sellers


SELECT
*
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.product_id IS NULL



SELECT
*
FROM order_items
WHERE seller_id IS NOT NULL


-- does number of sellers involved change late rate?

SELECT
order_id
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id


--- does delivery time buffer matter?
WITH delivery_time_buffer AS (SELECT
o.order_id,
EXTRACT(DAY FROM (oi.shipping_limit_date - o.order_purchase_timestamp)) AS delivery_time_buffer
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
)
SELECT
dtb.delivery_time_buffer,
COUNT(*),
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM
orders o
LEFT JOIN delivery_time_buffer dtb ON o.order_id = dtb.order_id
GROUP BY delivery_time_buffer




