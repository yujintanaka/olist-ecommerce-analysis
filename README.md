# SQL Query Repository for E-commerce Analysis

This repository contains SQL queries used for analyzing the Olist E-commerce dataset. For detailed analysis and insights, please refer to the following articles:

- [E-commerce Delivery Analysis: Optimizing Shipping Performance](https://medium.com/@yntanaka2000/e-commerce-delivery-analysis-fd6b703598ec)

## Data Preprocessing & Database Setup ##

1. Initial Data Exploration
- Analyzed raw CSV files using Python pandas
- Checked for missing values, duplicates, and data quality issues
- Found ~600 products missing descriptions but with dimensions
- Identified inconsistent city name spellings (e.g. "sao paulo" vs "são paulo")
- Discovered multiple geolocation entries per zip code
- Found missing product category translations

2. Database Schema Creation
- Created normalized tables with appropriate data types and constraints
- Added foreign key relationships between tables
- Defined composite primary keys where needed
- Added indexes for commonly queried columns

3. Data Loading & Cleaning
- Loaded raw CSV data into staging tables
- Performed data type casting and validation
- Consolidated geolocation data by zip code using median coordinates
- Added missing product category translations
- Cleaned and standardized text fields
- Verified data integrity and relationships

4. Key Data Quality Improvements
- Aggregated duplicate geolocation entries to single row per zip code
- Added English translations for all product categories
- Fixed typos in column names (length vs lenght)
- Preserved all order/review data even with missing timestamps
- Maintained data relationships while cleaning

The final database contains clean, validated data with proper relationships between customers, orders, products, sellers, and all related entities.
