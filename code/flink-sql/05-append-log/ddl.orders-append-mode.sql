create table if not exists orders (
    order_id INT primary key not enforced,
    user_id STRING,
    product_id STRING,
    quantity INT
) DISTRIBUTED into 1 BUCKETS 
with (
    'changelog.mode' = 'append',
    'value.fields-include' = 'all'
);