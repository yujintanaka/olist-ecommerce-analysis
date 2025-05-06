-- Customer Behavior Analysis
-- 1. Customer Purchase Patterns
WITH customer_orders AS (
    SELECT 
        c.customer_id,
        COUNT(DISTINCT o.order_id) as total_orders,
        AVG(p.payment_value) as avg_order_value,
        SUM(p.payment_value) as total_spent,
        MIN(o.order_purchase_timestamp) as first_purchase,
        MAX(o.order_purchase_timestamp) as last_purchase
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) as total_customers,
    ROUND(AVG(total_orders)::numeric, 2) as avg_orders_per_customer,
    ROUND(AVG(avg_order_value)::numeric, 2) as avg_order_value,
    ROUND(AVG(total_spent)::numeric, 2) as avg_customer_lifetime_value,
    ROUND(AVG(DATE_PART('day', last_purchase - first_purchase))::numeric, 2) as avg_customer_lifetime_days
FROM customer_orders;

-- 2. Payment Method Preferences
SELECT 
    payment_type,
    COUNT(*) as number_of_transactions,
    ROUND(AVG(payment_value)::numeric, 2) as avg_transaction_value,
    ROUND(AVG(payment_installments)::numeric, 2) as avg_installments
FROM payments
GROUP BY payment_type
ORDER BY number_of_transactions DESC;

-- 3. Customer Geographic Distribution
SELECT 
    c.customer_state,
    COUNT(DISTINCT c.customer_id) as number_of_customers,
    COUNT(DISTINCT o.order_id) as number_of_orders,
    ROUND(AVG(p.payment_value)::numeric, 2) as avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_state
ORDER BY number_of_customers DESC;

-- 4. Customer Review Behavior
SELECT 
    review_score,
    COUNT(*) as number_of_reviews,
    ROUND(AVG(DATE_PART('hour', review_answer_timestamp - review_creation_date))::numeric, 2) as avg_response_time_hours
FROM reviews
GROUP BY review_score
ORDER BY review_score;

-- 5. Purchase Time Analysis
SELECT 
    EXTRACT(HOUR FROM order_purchase_timestamp) as hour_of_day,
    COUNT(*) as number_of_orders,
    ROUND(AVG(p.payment_value)::numeric, 2) as avg_order_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 6. Customer Satisfaction vs Delivery Performance
SELECT 
    o.order_status,
    COUNT(*) as number_of_orders,
    ROUND(AVG(r.review_score)::numeric, 2) as avg_review_score,
    ROUND(AVG(DATE_PART('day', o.order_delivered_customer_date - o.order_purchase_timestamp))::numeric, 2) as avg_delivery_days
FROM orders o
LEFT JOIN reviews r ON o.order_id = r.order_id
GROUP BY o.order_status
ORDER BY number_of_orders DESC;



