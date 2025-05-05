CREATE TABLE orders (
  order_id STRING, 
  customer_id INT, 
  product_ids ARRAY<BIGINT>,
  price DECIMAL(10,2),
  order_details STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/Users/jerome/Code/ReadOnlyRepos/flink-studies/flink-sql/data/orders.csv',
    'format' = 'csv'
);