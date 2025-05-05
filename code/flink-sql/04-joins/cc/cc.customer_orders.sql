create table customer_order_count 
as select 
  window_start,
  window_end,
  count(order_id) as cnt 
from table(tumble( table `prod`.`marketplace`.`orders`, descriptor(`$rowtime`), interval '1' minutes)) 
group by window_start, window_end, `customer_id`;