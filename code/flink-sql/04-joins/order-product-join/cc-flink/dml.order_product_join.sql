create table d04_order_product_join (
    order_id INT,
    total_amount DOUBLE,
    customer_name VARCHAR,
    order_ts_raw TIMESTAMP(3),
    product_id INT,
    product_name STRING,
    primary key(order_id) not enforced
) distributed by(order_id) into 1 buckets
WITH (
   'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
)
as select
   o.id as order_id,
   o.total_amount,
   o.customer_name,
   o.order_ts_raw,
   o.product_id,
   p.product_name
from d04_orders o
join d04_products p on o.product_id = p.id;