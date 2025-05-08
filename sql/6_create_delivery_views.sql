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
)
SELECT
-- each order is tied to 1 shipment, but can have multiple products
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    AVG(r.review_score) AS average_review_score,
    -- aggregates over multiple payment methods
    SUM(p.payment_value) AS total_payment_value,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - order_estimated_delivery_date)) AS delay_time,
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '-5 days' THEN 'Very Early'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '1 days' THEN 'ontime'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '10 days' THEN 'Late'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) >= INTERVAL '10 days' THEN 'Very Late'
        ELSE 'Not Delivered'
    END AS delivery_performance,
    os.nth_order
FROM orders o
LEFT JOIN reviews r ON o.order_id = r.order_id
LEFT JOIN payments p ON o.order_id = p.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_sequence os ON o.order_id = os.order_id
GROUP BY o.order_id, os.nth_order
ORDER BY order_purchase_timestamp
-- 2. Aggregate on Unique Customer ID
-- For each unique customer ID: need the following:
-- First order info



-- View for Identifying BAD sellers
-- distance, weight, freight cost, 
SELECT
o.order_id AS order_id,
oi.seller_id AS seller_id,
o.order_status AS order_status,
o.order_purchase_timestamp AS purchase_date,
o.order_approved_at AS approved_date,
o.order_delivered_carrier_date AS carrier_date,
o.order_delivered_customer_date AS customer_date,
o.order_estimated_delivery_date AS estimate_date,
oi.shipping_limit_date AS shipping_limit_date,
oi.freight_value AS freight_value,
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
LIMIT 50;
