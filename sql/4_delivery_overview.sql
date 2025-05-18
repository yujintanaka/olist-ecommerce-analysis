-- How are we doing on delivery?

-- Overall delivery performance
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AGE(order_delivered_customer_date, order_purchase_timestamp)) AS median_delivery_time,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AGE(order_delivered_customer_date, order_estimated_delivery_date)) AS median_delivery_performance
FROM orders
WHERE order_status = 'delivered'

-- Delivery time as a histogram
SELECT    
    CASE
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '3 days' THEN 1
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '7 days' THEN 2
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '14 days' THEN 3
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '30 days' THEN 4
        ELSE 5
    END AS index,
    CASE
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '14 days' THEN '7-14 days'
        WHEN AGE(order_delivered_customer_date, order_purchase_timestamp) < INTERVAL '30 days' THEN '14-30 days'
        ELSE '30+ days'
    END AS delivery_time,
    COUNT(*) AS count
FROM orders
WHERE order_status = 'delivered'
GROUP BY delivery_time, index
ORDER BY index;


-- Delivery performance as a histogram
SELECT
    CASE
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '0 days' THEN 'On Time'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '3 days' THEN '1-3 days Late'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '7 days' THEN '3-7 days Late'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '14 days' THEN '7-14 days Late'
        ELSE '14+ days Late'
    END AS delivery_performance,
    COUNT(*) AS count
FROM orders
WHERE order_status = 'delivered'
GROUP BY delivery_performance
ORDER BY count DESC;

-- Median late delivery time
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AGE(order_delivered_customer_date, order_estimated_delivery_date)) AS median_late_delivery_time
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date > order_estimated_delivery_date;

-- Late delivery time as a histogram
SELECT
    CASE
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '1 day' THEN '0-1 days'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '3 days' THEN '1-3 days'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '7 days' THEN '3-7 days'
        WHEN AGE(order_delivered_customer_date, order_estimated_delivery_date) < INTERVAL '14 days' THEN '7-14 days'
        ELSE '14+ days'
    END AS late_delivery_time,
    COUNT(*) AS count
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date > order_estimated_delivery_date
GROUP BY late_delivery_time
ORDER BY count DESC;



-- On time and Late delivery rate with counts
SELECT
    CASE
        WHEN order_delivered_customer_date - order_estimated_delivery_date > INTERVAL '0 DAY' THEN 'late'
        ELSE 'on-time'
    END AS delivery_performance,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM orders
WHERE order_status = 'delivered'
GROUP BY delivery_performance
ORDER BY delivery_performance;

-- Deliveries in progress
SELECT
order_status,
COUNT(*) AS count,
COUNT(*) - COUNT(order_purchase_timestamp) AS null_purchase,
COUNT(*) - COUNT(order_approved_at) AS null_approval,
COUNT(*) - COUNT(order_delivered_carrier_date) AS null_carrier,
COUNT(*) - COUNT(order_delivered_customer_date) AS null_customer,
COUNT(*) - COUNT(order_estimated_delivery_date) AS null_estimate
FROM orders
GROUP BY order_status
ORDER BY count;
-- Note: unavailable items still get approved, but the carrier does not recieve.
-- Therefore, if we want to look into products that were previously marked unavailable,
-- we will have to look for very long times between approval and carrier
