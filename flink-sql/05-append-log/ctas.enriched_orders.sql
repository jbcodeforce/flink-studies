create table enriched_orders (
  order_id int primary key not enforced
)
distributed by(order_id) into 1 buckets
with (
  'changelog.mode'='upsert',
   'value.fields-include' = 'all'  -- keep order_id in value schema
) as
select 
    o.order_id,
    o.user_id,
    o.product_id,
    p.description,
    p.organic,
    o.quantity
from orders as o
left join products as p ON o.product_id = p.product_id