CREATE TABLE d16_order_count (
  product_id  STRING,
  cnt BIGINT,
  PRIMARY KEY(product_id) NOT ENFORCED
) DISTRIBUTED BY (product_id) INTO 4 BUCKETS 
WITH (
    'changelog.mode'        = 'upsert',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset',
    'scan.bounded.mode'     = 'unbounded'
)
