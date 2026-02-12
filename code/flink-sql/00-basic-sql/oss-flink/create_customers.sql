 CREATE TABLE customers (
  customer_id BIGINT, 
  name STRING, 
  address STRING,
  postcode STRING,
  city STRING, 
  email STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
)  WITH ( 
    'connector' = 'filesystem',
    'path' = '../../data/customers.csv',
    'format' = 'csv'
);