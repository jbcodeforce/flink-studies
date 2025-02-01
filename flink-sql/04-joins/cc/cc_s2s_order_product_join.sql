select 
   o.order_id,
   o.product_id,
   p.product_name
from orders
left joins products on o.product_id = p.id;