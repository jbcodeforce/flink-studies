SET 'client.statement-name' = 'unique-orders-maintenance';
SET 'sql.state-ttl' = '1 hour';

CREATE TABLE unique_orders 
AS SELECT 
  order_id, 
  product_id, 
  customer_id, 
  price
FROM (
   SELECT * ,
          ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY `$rowtime` ASC) AS rownum
   FROM `examples`.`marketplace`.`orders`
      )
WHERE rownum = 1;