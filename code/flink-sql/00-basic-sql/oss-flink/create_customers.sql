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
    'path' = '/Users/jerome/Documents/Code/flink-studies/code/flink-sql/data/customers.csv',
    'format' = 'csv'
);