-- How are we doing on delivery?

-- Select median delivery time which is purchase date - customer delivered date
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AGE(order_delivered_customer_date, order_purchase_timestamp)) AS median_delivery_time,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AGE(order_delivered_customer_date, order_estimated_delivery_date)) AS median_delivery_performance
    -- I want to add the delivery performance when the order is delayed
FROM orders
WHERE order_status = 'delivered'