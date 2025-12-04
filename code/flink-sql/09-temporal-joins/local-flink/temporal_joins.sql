use catalog default_catalog;
use default_database;

CREATE TABLE orders (
    order_id    STRING,
    price       DECIMAL(10,2),
    currency    STRING,
    order_time  TIMESTAMP(3),
    WATERMARK FOR order_time AS order_time,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'filesystem',
    'path' = '/Users/jerome/Documents/Code/flink-studies/code/flink-sql/09-temporal-joins/local-flink/data/orders.csv',
    'format' = 'csv',
    'csv.ignore-first-line' = 'false'
);

CREATE TABLE currency_rates (
    currency STRING,
    conversion_rate DECIMAL(10, 2),
    update_time TIMESTAMP(3),
    WATERMARK FOR update_time AS update_time,
    PRIMARY KEY (currency) NOT ENFORCED
) WITH (
    'connector' = 'filesystem',
    'path' = '/Users/jerome/Documents/Code/flink-studies/code/flink-sql/09-temporal-joins/local-flink/data/currency_rates.csv',
    'format' = 'csv'
);

CREATE TABLE orders_with_currency_rates (
    order_id    STRING,
    price       DECIMAL(10,2),
    currency    STRING,
    order_time  TIMESTAMP(3),
    conversion_rate DECIMAL(10,2),
    usd_converted_amount DECIMAL(10,2)
) WITH (
    'connector' = 'filesystem',
    'path' = '/Users/jerome/Documents/Code/flink-studies/code/flink-sql/09-temporal-joins/local-flink/data/orders_with_currency_rates.csv',
    'format' = 'csv'
);

insert into orders_with_currency_rates
SELECT
  order_id,
  price,  -- original price
  orders.currency,
  order_time,
  currency_rates.conversion_rate,
  price * currency_rates.conversion_rate as usd_converted_amount
FROM orders
LEFT JOIN currency_rates FOR SYSTEM_TIME AS OF orders.order_time
ON orders.currency = currency_rates.currency;

