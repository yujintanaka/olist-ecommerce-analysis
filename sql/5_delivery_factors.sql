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
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '1 day' THEN '1 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        ELSE '14+ days'
    END AS delivery_time,
    AVG(otd.distance_in_km) as avg_distance,
    COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN orders_time_distance otd ON o.order_id = otd.order_id
GROUP BY delivery_time
HAVING COUNT(*) >50
ORDER BY avg_distance;

-- Yes, distance is a significant factor, but also there are many slow deliveries even when the locations are close.


--Does distance cause lateness
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
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '0 days' THEN 'On Time'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '3 days' THEN '1-3 days Late'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '7 days' THEN '3-7 days Late'
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) < INTERVAL '14 days' THEN '7-14 days Late'
        ELSE '14+ days Late'
    END AS delivery_performance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY otd.distance_in_km) AS median_distance,
    COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN orders_time_distance otd ON o.order_id = otd.order_id
GROUP BY delivery_performance
HAVING COUNT(*) >50
ORDER BY median_distance;

-- How does weight affect delivery time?
SELECT
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '1 day' THEN '1 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        ELSE '14+ days'
    END AS delivery_time,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.product_weight_g) AS median_weight,
    COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY delivery_time
HAVING COUNT(*) >50
ORDER BY median_weight;

-- Yes, product weight is a factor

-- Does weight cause lateness?
SELECT
    CASE
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '0 days' THEN 'On Time'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '3 days' THEN '1-3 days Late'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '7 days' THEN '3-7 days Late'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '14 days' THEN '7-14 days Late'
        ELSE '14+ days Late'
    END AS delivery_performance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.product_weight_g) AS median_weight,
    COUNT(*) AS number_of_orders
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY delivery_performance
ORDER BY delivery_performance;

-- I would like to see distributions first, better to do this on python.



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



-- Where is the bottleneck? When not late
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
    AND order_delivered_customer_date < order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time
ORDER BY avg_delivery_time;
-- insight: bottlneck is mostly at the carrier level. Improving the seller efficiency at most gains few days
-- Seller efficiency gains as a percentage.

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


-- Shipping limit date
-- How many orders are meeting the shipping limit?
SELECT
    AVG(oi.shipping_limit_date - o.order_delivered_carrier_date)
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date > order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
LIMIT 10;
-- even late deliveries on average are recieved by the carrier before the shipping limit
-- For best improvements, I would suggest using the best carrier

-- People who pay extra for shipping and have it late must be pissed.. How often does that happen and is it significant?

-- shipping speed by freight value, controlled by distance and weight
-- seems like a job for python. Build a python view, export as CSV and move onto linear regression
-- Dollar value of delivery is also a python thing.


-- SO FAR, the factors that influence delivery speed is:
-- weight, distance, product type - proxy for weight, seller issues, freight cost

-- Expand on finding sellers that are causing issues: does a subset of sellers repeatedly make late?


SELECT
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '30 days' THEN '14-30 days'
        ELSE '30+ days'
    END AS delivery_time,
    AVG(oi.freight_value)
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date > order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time;
--Average freight costs are all similar, and if anything the later deliveries are more expensive

-- Freight costs when NOT late
SELECT
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        WHEN AGE(o.order_delivered_customer_date, o.order_purchase_timestamp) < INTERVAL '30 days' THEN '14-30 days'
        ELSE '30+ days'
    END AS delivery_time,
    AVG(oi.freight_value)
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date < order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time;

--segmentation analysis for bad sellers


-- Monthly on-time delivery rate with sellers
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    COUNT(DISTINCT oi.seller_id) AS unqiue_sellers,
    COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY purchase_month
HAVING COUNT(*)> 50
ORDER BY purchase_month;


-- Monthly on-time delivery rate 
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM orders o
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY purchase_month
HAVING COUNT(*)> 50
ORDER BY purchase_month;

-- Number of orders per month
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
    COUNT(*) AS number_of_orders
FROM orders
WHERE order_status = 'delivered'
    AND order_purchase_timestamp IS NOT NULL
GROUP BY order_month
ORDER BY order_month;


-- See monthly averages for: weight, distance,


-- 





-- Percentages of delivery time, seller to carrier, and carrier to customer when late compared to on time.
-- Want to see if there are cases where the fault is on the seller, and sometimes on the carrier, and sometimes on both.
-- Segment by delivery estimate time, and find the baseline non-late time for each segment.
-- then 
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
    AND order_delivered_customer_date < order_estimated_delivery_date
    AND order_delivered_customer_date  IS NOT NULL
    AND order_delivered_carrier_date  IS NOT NULL
    AND order_approved_at  IS NOT NULL
GROUP BY delivery_time
ORDER BY avg_delivery_time;

-- Compute average percentage of estimate time is between seller to carrier, and carrier to customer

-- for example, estimate is 30 days, and seller to carrier is 10 days, this is 33perc, and carrier to cust is 66.
-- Now, if we see deliveries where the seller is slower, this will show as the percentage will be larger than avg.

--Then, we can see if there are differences between late and non late orders.

-- The real ratio I want is:
-- What percentage is seller error? what percentage is carrier error? what percentage is both?
-- 



-- What percentage of late deliveries are caused by inventory unaviailability?







-- Want lines for review score, the delivery time but segmented by days late
-- average score grouped by delivery time, but separate columns for performance
-- Column 1: delivery time, column 2: 1 day late percentage 1 star, column 3: 2 days late percentage 1 star



SELECT
    EXTRACT(DAY FROM AGE(o.order_delivered_customer_date, o.order_purchase_timestamp)) AS delivery_time,
    COUNT(*) FILTER (WHERE r.review_score = 1) * 100.0 / COUNT(*) AS percentage_1_star_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
GROUP BY delivery_time
ORDER BY delivery_time;


WITH time_delay_score AS( SELECT
    EXTRACT(DAY FROM AGE(o.order_delivered_customer_date, o.order_purchase_timestamp)) AS delivery_time,
    EXTRACT(DAY FROM AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date)) AS days_late,
    r.review_score
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
)
SELECT
tds.delivery_time,
COUNT(*) FILTER(WHERE days_late = 5)
FROM time_delay_score tds
GROUP BY tds.delivery_time


WITH time_delay_score AS( SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    DATE_PART('day', o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_time,
    DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date) AS days_late,
    r.review_score
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
)
SELECT
tds.delivery_time,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 0) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 0) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 0)
    ELSE NULL 
END AS zero_days_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 1) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 1) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 1)
    ELSE NULL 
END AS one_day_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 2) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 2) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 2)
    ELSE NULL 
END AS two_days_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 3) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 3) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 3)
    ELSE NULL 
END AS three_days_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 4) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 4) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 4)
    ELSE NULL 
END AS four_days_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 5) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 5) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 5)
    ELSE NULL 
END AS five_days_late,
CASE 
    WHEN COUNT(*) FILTER (WHERE tds.days_late = 6) >= 10 THEN 
        COUNT(*) FILTER (WHERE tds.review_score = 1 AND tds.days_late = 6) * 100.0 / COUNT(*) FILTER (WHERE tds.days_late = 6)
    ELSE NULL 
END AS six_days_late
FROM time_delay_score tds
GROUP BY tds.delivery_time
ORDER BY tds.delivery_time
LIMIT 30;



-- Are sellers first orders worse?
WITH sales_sequence AS (SELECT
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY oi.seller_id
        ORDER BY o.order_purchase_timestamp
    ) AS nth_sale
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, oi.seller_id, o.order_purchase_timestamp
)
SELECT
ss.nth_sale,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) AS number_late,
COUNT(*) as number_sales
FROM sales_sequence ss
LEFT JOIN orders o ON ss.order_id = o.order_id
GROUP BY ss.nth_sale
HAVING COUNT(*)>700
ORDER BY on_time_delivery_rate
-- first orders don't really have the worst rates


--Does seller experience matter? total number sales with rate for that group of sellers

WITH seller_experience AS ( SELECT
COUNT(*) AS number_sales,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
MODE() WITHIN GROUP (ORDER BY p.product_category_name) AS product_category
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY oi.seller_id
ORDER BY number_sales
)
SELECT
 se.number_sales,
 AVG(se.on_time_delivery_rate) AS avg_delivery_rate,
 COUNT(*) AS number_sellers,
 COUNT(*) * se.number_sales AS total_sales,
 MODE() WITHIN GROUP (ORDER BY se.product_category) AS most_frequent_category
FROM seller_experience se
GROUP BY se.number_sales
ORDER BY se.number_sales



SELECT
oi.seller_id,
COUNT(*) as count
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'

GROUP BY seller_id
ORDER BY count DESC;


SELECT
o.*,
EXTRACT(DAY FROM (o.order_delivered_customer_date - order_estimated_delivery_date)) AS delay_time,
p.product_category_name
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE seller_id = '88460e8ebdecbfecb5f9601833981930'
ORDER BY o.order_purchase_timestamp


SELECT
c.customer_state,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id = '1f50f920176fa81dab994f9023523100'
    AND order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY c.customer_state
ORDER BY on_time_delivery_rate


SELECT
c.customer_state,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id = '7c67e1448b00f6e969d365cea6b010ab'
    AND order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY c.customer_state
ORDER BY on_time_delivery_rate




-- first time seller performance over time - perhaps a good indication of delivery market
WITH sales_sequence AS (SELECT
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY oi.seller_id
        ORDER BY o.order_purchase_timestamp
    ) AS nth_sale
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, oi.seller_id, o.order_purchase_timestamp
)
SELECT
DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) AS number_late,
COUNT(*) as number_sales
FROM sales_sequence ss
LEFT JOIN orders o ON ss.order_id = o.order_id
WHERE nth_sale =1
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
HAVING COUNT(*)>50
ORDER BY month


-- experienced sellers performance over time

WITH sales_sequence AS (SELECT
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY oi.seller_id
        ORDER BY o.order_purchase_timestamp
    ) AS nth_sale
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, oi.seller_id, o.order_purchase_timestamp
)
SELECT
DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) AS number_late,
COUNT(*) as number_sales
FROM sales_sequence ss
LEFT JOIN orders o ON ss.order_id = o.order_id
WHERE nth_sale > 50
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
HAVING COUNT(*)>50
ORDER BY month


--- Brackets of: first order, 
WITH sales_sequence AS (SELECT
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY oi.seller_id
        ORDER BY o.order_purchase_timestamp
    ) AS nth_sale
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, oi.seller_id, o.order_purchase_timestamp
)
SELECT
DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale = 1) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale = 1) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale = 1), 0)
END AS otd_1,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale BETWEEN 2 AND 4) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale BETWEEN 2 AND 4) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale BETWEEN 2 AND 4), 0)
END AS otd_2_4,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale BETWEEN 5 AND 8) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale BETWEEN 5 AND 8) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale BETWEEN 5 AND 8), 0)
END AS otd_5_8,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale BETWEEN 9 AND 15) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale BETWEEN 9 AND 15) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale BETWEEN 9 AND 15), 0)
END AS otd_9_15,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale BETWEEN 16 AND 25) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale BETWEEN 16 AND 25) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale BETWEEN 16 AND 25), 0)
END AS otd_16_25,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale BETWEEN 26 AND 50) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale BETWEEN 26 AND 50) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale BETWEEN 26 AND 50), 0)
END AS otd_26_50,
CASE 
    WHEN COUNT(*) FILTER (WHERE nth_sale > 50) < 20 THEN NULL
    ELSE COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date AND nth_sale > 50) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE nth_sale > 50), 0)
END AS otd_50_plus
FROM sales_sequence ss
LEFT JOIN orders o ON ss.order_id = o.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
HAVING COUNT(*)>50
ORDER BY month




-- seasonality. lets check christmas supplies and when they are ordered

SELECT
COUNT(*) AS number_orders,
DATE_TRUNC('month', o.order_purchase_timestamp) AS month
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_category_name = 'sports_leisure'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month



-- WHich products were late?
SELECT
COUNT(*) AS number_sales,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
p.product_category_name
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY p.product_category_name
HAVING COUNT(*)>50
ORDER BY on_time_delivery_rate



-- congestion by region sellers
SELECT
s.seller_state,
COUNT(*) AS num_orders,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY s.seller_state
ORDER BY on_time_delivery_rate

--congestion by region customer
SELECT
c.customer_state,
COUNT(*) AS num_orders,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY c.customer_state
ORDER BY on_time_delivery_rate

-- congestion by region over time
SELECT
DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
COUNT(*) AS num_orders,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND s.seller_state = 'SP'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month


-- Checking routes that are most congested.
SELECT
CONCAT(s.seller_state, c.customer_state) AS route,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'

GROUP BY route
HAVING COUNT(*) >40
ORDER BY on_time_delivery_rate


SELECT
CONCAT(s.seller_state, c.customer_state) AS route,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-01-01'

GROUP BY route
HAVING COUNT(*) >40
ORDER BY on_time_delivery_rate





--- On time delivery rate by recieving city


SELECT
c.customer_state,
COUNT(*) FILTER (WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date) * 100.0 / COUNT(*) AS on_time_delivery_rate,
COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND DATE_TRUNC('month', o.order_purchase_timestamp) = '2018-03-01'
GROUP BY c.customer_state
ORDER BY on_time_delivery_rate


-- otd by customer state
SELECT
c.customer_state,
DATE_TRUNC('month', o.order_delivered_carrier_date + (EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 2) * INTERVAL '1 day') AS transit_month,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL



-- otd by month but only SP
SELECT
DATE_TRUNC('month', o.order_delivered_carrier_date + (EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 2) * INTERVAL '1 day') AS transit_month,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE order_status = 'delivered'
    AND s.seller_state ='SP'
    AND c.customer_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL



-- otd by month but only SP
SELECT
DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE order_status = 'delivered'
    AND s.seller_state ='SP'
    AND c.customer_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL

--otd but seller NOT SP, customer SP
    SELECT
s.seller_state,
DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
END AS late
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers s ON s.seller_id = oi.seller_id
WHERE order_status = 'delivered'
    AND (NOT (s.seller_state = 'SP'))
    AND c.customer_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL




    -- Estimate delivery length by month
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    AVG(EXTRACT(DAY FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp))) AS avg_estimated_length
FROM orders o
WHERE order_status = 'delivered'
    AND order_estimated_delivery_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;




-- What causes the late deliveries by location, inbound and outbound.
-- For each row, create two rows 1 for inbound and 1 for outbound


WITH outbound_states AS (
    SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    CONCAT(s.seller_state,'_OUTBOUND') AS state,
    CONCAT(c.customer_state,'_INBOUND') AS counterparty,
    CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
    END AS late
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN sellers s ON oi.seller_id = s.seller_id
),
inbound_states AS (
    SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    CONCAT(c.customer_state,'_INBOUND') AS state,
    CONCAT(s.seller_state,'_OUTBOUND') AS counterparty,
    CASE
    WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
    ELSE 0
    END AS late
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN sellers s ON oi.seller_id = s.seller_id
),
combined_states AS (
SELECT purchase_month, state, late, counterparty
FROM outbound_states
UNION ALL
SELECT
purchase_month, state, late, counterparty
FROM inbound_states
)
SELECT
state,
AVG(late) AS late_rate,
MODE() WITHIN GROUP (ORDER BY CASE WHEN late = 1 THEN counterparty ELSE NULL END) AS most_frequent_late_counterparty,
MODE() WITHIN GROUP (ORDER BY CASE WHEN late = 0 THEN counterparty ELSE NULL END) AS most_frequent_ontime_counterparty,
MODE() WITHIN GROUP (ORDER BY counterparty) AS most_frequent_counterparty
FROM combined_states
WHERE purchase_month = '2018-03-01 00:00:00'
GROUP BY state
ORDER BY late_rate;



SELECT
CONCAT(s.seller_state,'_OUTBOUND') AS state,
COUNT(*)
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
GROUP BY state
ORDER BY count


-- tableau viz, need late rate by inbound state over time
-- will make a slider 
-- purchase date, late or not, inbound state for SP
SELECT
    c.customer_state,

    o.order_purchase_timestamp,
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
        ELSE 0
    END AS late,
    'Brazil' AS country
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE order_status = 'delivered'
    AND s.seller_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL




-- zip code dots
SELECT
    o.order_id,
    g.geolocation_lat,
    g.geolocation_lng,
    o.order_purchase_timestamp,
    CASE
        WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1
        ELSE 0
    END AS late
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN geolocation g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE order_status = 'delivered'
    AND s.seller_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL




-- Time to carrier by month
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    AVG(EXTRACT(DAY FROM (o.order_delivered_carrier_date - o.order_purchase_timestamp))) AS avg_time_to_carrier
FROM orders o
WHERE order_delivered_carrier_date IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;


-- outbound logistics check for places other than SP
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    AVG(CASE WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1 ELSE 0 END) AS avg_late_rate,
    COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND s.seller_state != 'SP'
    AND c.customer_state != 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;

-- Checking the case when it is outbound from SP -- increase is proportional.
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    AVG(CASE WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1 ELSE 0 END) AS avg_late_rate,
    COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND s.seller_state = 'SP'
    AND c.customer_state != 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;

-- Orders TO sao paulo
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
    AVG(CASE WHEN AGE(o.order_delivered_customer_date, o.order_estimated_delivery_date) > INTERVAL '0 day' THEN 1 ELSE 0 END) AS avg_late_rate,
    COUNT(*)
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE order_status = 'delivered'
    AND s.seller_state != 'SP'
    AND c.customer_state = 'SP'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;