CREATE TABLE IF NOT EXISTS shipped_orders (
  PRIMARY KEY(order_id) NOT ENFORCED
) DISTRIBUTED BY (order_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all'
) as SELECT
  o.order_id as order_id,
  o.total_amount as total,
  o.customer_name as customer,
  s.id as shipment_id,
  s.ship_ts_raw as shipment_ts,
  s.warehouse,
  TIMESTAMPDIFF(HOUR,
             o.order_ts_raw,                     -- convert numeric type (an epoch based timestamp in this case) to a formatted string in the default format of yyyy-MM-dd HH:mm:ss
             s.ship_ts_raw) as HR_TO_SHIP
  FROM d04_order_product_join o
  INNER JOIN d04_shipments s
  ON o.order_id = s.order_id
      AND s.ship_ts_raw
      BETWEEN o.order_ts_raw
      AND o.order_ts_raw  + INTERVAL '2' DAY;
