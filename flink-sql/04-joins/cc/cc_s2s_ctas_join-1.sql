create table IF NOT EXISTS order_enriched  (
  PRIMARY KEY(id) NOT ENFORCED
) DISTRIBUTED BY (id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all'
) as select 
   o.id,
   o.product_id,
   p.product_name
from orders o 
left join products p on o.product_id = p.id;
