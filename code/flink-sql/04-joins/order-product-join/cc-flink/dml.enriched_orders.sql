insert into d04_enriched_orders
select  /*+ STATE_TTL(o='2h', p='30d') */ 
   o.id as order_id,
   o.total_amount,
   o.customer_name,
   o.order_ts_raw,
   o.product_id,
   p.product_name
from d04_orders o
left join d04_products p on o.product_id = p.id;