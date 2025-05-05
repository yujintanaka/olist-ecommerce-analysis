import pandas as pd
from sqlalchemy import create_engine

engine = create_engine('postgresql+psycopg2://postgres:Randomx5@localhost:5432/olist_ecommerce')

customers =  pd.read_csv('data_csv/olist_customers_dataset.csv')
geolocation =  pd.read_csv('data_csv/olist_geolocation_dataset.csv')
order_items =  pd.read_csv('data_csv/olist_order_items_dataset.csv')
order_payments =  pd.read_csv('data_csv/olist_order_payments_dataset.csv')
order_reviews =  pd.read_csv('data_csv/olist_order_reviews_dataset.csv')
orders =  pd.read_csv('data_csv/olist_orders_dataset.csv')
products =  pd.read_csv('data_csv/olist_products_dataset.csv')
sellers =  pd.read_csv('data_csv/olist_sellers_dataset.csv')
translation =  pd.read_csv('data_csv/product_category_name_translation.csv')


customers.to_sql('raw_customers', engine, if_exists='replace', index=False)
geolocation.to_sql('raw_geolocation', engine, if_exists='replace', index=False)
order_items.to_sql('raw_order_items', engine, if_exists='replace', index=False)
order_payments.to_sql('raw_order_payments', engine, if_exists='replace', index=False)
order_reviews.to_sql('raw_order_reviews', engine, if_exists='replace', index=False)
orders.to_sql('raw_orders', engine, if_exists='replace', index=False)
products.to_sql('raw_products', engine, if_exists='replace', index=False)
sellers.to_sql('raw_sellers', engine, if_exists='replace', index=False)
translation.to_sql('raw_translation', engine, if_exists='replace', index=False)

