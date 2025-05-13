-- How important is the delivery performance?
-- 1. Effect of delivery time on review score
SELECT
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
    AVG(r.review_score) AS avg_review_score,
    COUNT(*) AS number_of_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_time
ORDER BY delivery_time;


-- 2. Effect of delivery time on review score, given that the order was delivered on time
SELECT
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
    AVG(r.review_score) AS avg_review_score,
    COUNT(*) AS number_of_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date <= o.order_estimated_delivery_date  
GROUP BY delivery_time
ORDER BY delivery_time;
-- NOTE: faster delivery time is always better, even if the order was delivered on time

-- 3. Effect of delivery performance (distance from estimated delivery date) on review score
SELECT
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) AS delivery_performance,
    AVG(r.review_score) AS avg_review_score,
    COUNT(*) AS number_of_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_performance
ORDER BY delivery_performance;


-- 4. Analyzing subsequent order values per customer
WITH ordered_purchases AS (
    SELECT 
        c.customer_id,
        o.order_purchase_timestamp,
        SUM(oi.price) as order_value,
        LEAD(SUM(oi.price)) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_purchase_timestamp
        ) as next_order_value
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, o.order_purchase_timestamp
)
SELECT 
    customer_id,
    order_purchase_timestamp,
    order_value,
    next_order_value
FROM ordered_purchases
WHERE next_order_value IS NOT NULL
ORDER BY customer_id, order_purchase_timestamp;



SELECT
    c1.customer_id AS primary_customer_id,
    c2.customer_id AS secondary_customer_id,
    c1.customer_unique_id
FROM customers c1
LEFT JOIN customers c2 ON c1.customer_unique_id = c2.customer_unique_id
WHERE c1.customer_id != c2.customer_id
ORDER BY primary_customer_id, secondary_customer_id;


-- date, order_id, customer_id, customer_unique_id, price
WITH order_date_price AS(
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    oi.price,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
),
subsequent_order_value_90_days AS (
SELECT
    odp1.order_id AS primary_id,
    SUM(odp2.price) AS subsequent_order_value
FROM order_date_price odp1
LEFT JOIN order_date_price odp2 ON odp1.customer_unique_id = odp2.customer_unique_id
WHERE odp1.order_id != odp2.order_id
    AND odp1.order_delivered_customer_date IS NOT NULL
    AND odp1.order_delivered_customer_date < odp2.order_purchase_timestamp
    AND (odp1.order_delivered_customer_date + INTERVAL '90 days') > odp2.order_purchase_timestamp
    AND (odp1.order_delivered_customer_date + INTERVAL '90 days') <= (SELECT MAX(order_purchase_timestamp) FROM orders)
GROUP BY odp1.order_id
)
SELECT
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_time,
    AVG(r.review_score) AS avg_review_score,
    AVG(COALESCE(s.subsequent_order_value,0)) AS avg_subsequent_order_value,
    COUNT(*) AS number_of_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
JOIN subsequent_order_value_90_days s ON o.order_id = s.primary_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_time
ORDER BY delivery_time;


-- Dollar value of review score.

-- Time until next purchase based on review

SELECT
o.order_id,
r.review_score,
r.review_creation_date,
(
    SELECT MIN(next_o.order_purchase_timestamp)
    FROM orders next_o
    WHERE next_o.customer_id = c.customer_id
    AND next_o.order_purchase_timestamp > r.review_creation_date
) AS next_purchase_date
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
JOIN customers c ON o.customer_id = c.customer_id
LIMIT 10;
--GROUP BY r.review_score


WITH ReviewsWithTimestamps AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        r.review_score,
        r.review_creation_date,
        o.order_purchase_timestamp
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    JOIN customers c ON o.customer_id = c.customer_id
),
CustomerPurchases AS (
    SELECT 
        o.order_purchase_timestamp,
        c.customer_unique_id
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
),
next_purchase AS (SELECT
    rwt.order_id,
    rwt.review_score,
    MIN(cp.order_purchase_timestamp) - rwt.review_creation_date AS next_purchase_interval
FROM ReviewsWithTimestamps rwt
LEFT JOIN CustomerPurchases cp ON 
    rwt.customer_unique_id = cp.customer_unique_id AND
    cp.order_purchase_timestamp > rwt.review_creation_date
GROUP BY 
    rwt.order_id,
    rwt.review_score,
    rwt.review_creation_date
)
SELECT
np.review_score,
AVG(np.next_purchase_interval) AS avg_time_to_next_purchase,
COUNT(*) AS made_additional_purchase
FROM next_purchase np
GROUP BY np.review_score

