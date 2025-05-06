-- Why do we have delivery issues?

-- Delivery time by distance: customer date, purchase date, customer zip code, seller zip code
WITH orders_time_distance AS (SELECT
    o.order_id,
    o.customer_id,
    s.seller_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    s.seller_zip_code_prefix,
    c.customer_zip_code_prefix,
    -- Haversine formula for calculating distance between two points on Earth
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
    ) AS distance_in_km
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN geolocation gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix
LEFT JOIN geolocation gs ON s.seller_zip_code_prefix = gs.geolocation_zip_code_prefix
)
SELECT
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        ELSE '14+ days'
    END AS delivery_time,
    AVG(otd.distance_in_km),
    COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN orders_time_distance otd ON o.order_id = otd.order_id
GROUP BY delivery_time
ORDER BY delivery_time;

-- Yes, distance is a significant factor, but also there are many slow deliveries even when the locations are close.


-- How does weight affect delivery time?
SELECT
EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
AVG(p.product_weight_g),
COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY delivery_time
ORDER BY delivery_time;
-- Yes, product weight is a factor



--In order to improve delivery times, we have to find anomalies based on weight and distance.
-- We can categorize orders by fast, normal, slow or anomaly factor numerical variable.
-- anomaly factor variable can be std deviation from expected.

-- What are the common factors in very slow deliveries?
-- What percentage of sellers make up the bad deliveries?

-- identify outliers: 2 std deviation away from expected.
-- Further investigation by talking to slow sellers which company they are using etc.


-- delivery time by product category name
SELECT
AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))) AS avg_delivery_time,
p.product_category_name,
COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY avg_delivery_time;
-- Obviously furniture takes a lot of time but mostly the delivery times are quite close.
-- This means that the long delivery times are due to incompetence, not due to the product.



-- Where is the bottleneck?
SELECT
    CASE
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '30 days' THEN '14-30 days'
        ELSE '30+ days'
    END AS delivery_time,
    COUNT(*) AS count,
    EXTRACT( HOUR FROM AVG(order_approved_at - order_purchase_timestamp)) || ' hours' AS purchase_to_approval,
    EXTRACT( DAY FROM AVG(order_delivered_carrier_date - order_approved_at)) || ' days' AS approval_to_carrier,
    EXTRACT( DAY FROM AVG(order_delivered_customer_date - order_delivered_carrier_date)) ||' days' AS carrier_to_customer,
    AVG(AGE(order_delivered_customer_date, order_purchase_timestamp)) AS avg_delivery_time

FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time
ORDER BY avg_delivery_time;
-- insight: bottlneck is mostly at the carrier level. Improving the seller efficiency at most gains few days

SELECT
    CASE
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '30 days' THEN '14-30 days'
        ELSE '30+ days'
    END AS delivery_time,
    COUNT(*) AS count,
    EXTRACT( HOUR FROM AVG(order_approved_at - order_purchase_timestamp)) || ' hours' AS purchase_to_approval,
    EXTRACT( DAY FROM AVG(order_delivered_carrier_date - order_approved_at)) || ' days' AS approval_to_carrier,
    EXTRACT( DAY FROM AVG(order_delivered_customer_date - order_delivered_carrier_date)) ||' days' AS carrier_to_customer,
    AVG(AGE(order_delivered_customer_date, order_purchase_timestamp)) AS avg_delivery_time

FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date > order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time
ORDER BY avg_delivery_time;


