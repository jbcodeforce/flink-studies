select 
   o.id,
   o.product_id,
   p.product_name
from orders o 
left join products p on o.product_id = p.id;
