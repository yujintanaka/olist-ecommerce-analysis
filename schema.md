# Olist E-commerce Database Schema

This document outlines the database schema for the Olist E-commerce dataset. The schema consists of 8 tables that store information about customers, orders, products, sellers, and related data.

## Tables

### customers
Stores customer information.

| Column | Type | Description |
|--------|------|-------------|
| customer_id | VARCHAR | Primary Key |
| customer_unique_id | VARCHAR | Unique identifier for the customer |
| customer_zip_code_prefix | INTEGER | Customer's zip code prefix |
| customer_city | VARCHAR | Customer's city |
| customer_state | VARCHAR | Customer's state |

### orders
Stores order information.

| Column | Type | Description |
|--------|------|-------------|
| order_id | VARCHAR | Primary Key |
| customer_id | VARCHAR | Foreign Key to customers table |
| order_status | VARCHAR | Status of the order |
| order_purchase_timestamp | TIMESTAMP | When the order was purchased |
| order_approved_at | TIMESTAMP | When the order was approved |
| order_delivered_carrier_date | TIMESTAMP | When the order was delivered to carrier |
| order_delivered_customer_date | TIMESTAMP | When the order was delivered to customer |
| order_estimated_delivery_date | TIMESTAMP | Estimated delivery date |

### order_items
Stores individual items within orders.

| Column | Type | Description |
|--------|------|-------------|
| order_id | VARCHAR | Part of Primary Key, Foreign Key to orders table |
| order_item_id | INTEGER | Part of Primary Key |
| product_id | VARCHAR | Foreign Key to products table |
| seller_id | VARCHAR | Foreign Key to sellers table |
| shipping_limit_date | TIMESTAMP | Shipping deadline |
| price | NUMERIC | Price of the item |
| freight_value | NUMERIC | Freight cost |

### products
Stores product information.

| Column | Type | Description |
|--------|------|-------------|
| product_id | VARCHAR | Primary Key |
| product_category_name | VARCHAR | Product category name |
| product_name_length | INTEGER | Length of product name |
| product_description_length | INTEGER | Length of product description |
| product_photos_qty | INTEGER | Number of product photos |
| product_weight_g | INTEGER | Product weight in grams |
| product_length_cm | INTEGER | Product length in centimeters |
| product_height_cm | INTEGER | Product height in centimeters |
| product_width_cm | INTEGER | Product width in centimeters |

### sellers
Stores seller information.

| Column | Type | Description |
|--------|------|-------------|
| seller_id | VARCHAR | Primary Key |
| seller_zip_code_prefix | INTEGER | Seller's zip code prefix |
| seller_city | VARCHAR | Seller's city |
| seller_state | VARCHAR | Seller's state |

### geolocation
Stores geographical location data.

| Column | Type | Description |
|--------|------|-------------|
| geolocation_zip_code_prefix | INTEGER | Zip code prefix |
| geolocation_lat | NUMERIC | Latitude |
| geolocation_lng | NUMERIC | Longitude |
| geolocation_city | VARCHAR | City name |
| geolocation_state | VARCHAR | State name |

### reviews
Stores customer reviews.

| Column | Type | Description |
|--------|------|-------------|
| review_id | VARCHAR | Review identifier |
| order_id | VARCHAR | Foreign Key to orders table |
| review_score | INTEGER | Review score |
| review_creation_date | TIMESTAMP | When the review was created |
| review_answer_timestamp | TIMESTAMP | When the review was answered |

### payments
Stores payment information.

| Column | Type | Description |
|--------|------|-------------|
| order_id | VARCHAR | Foreign Key to orders table |
| payment_sequential | INTEGER | Sequential payment number |
| payment_type | VARCHAR | Type of payment |
| payment_installments | INTEGER | Number of payment installments |
| payment_value | NUMERIC | Payment value |

## Relationships

- `orders.customer_id` references `customers.customer_id`
- `order_items.order_id` references `orders.order_id`
- `order_items.product_id` references `products.product_id`
- `order_items.seller_id` references `sellers.seller_id`
- `reviews.order_id` references `orders.order_id`
- `payments.order_id` references `orders.order_id` 