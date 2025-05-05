CREATE TABLE IF NOT EXISTS shipped_orders (
  PRIMARY KEY(order_id) NOT ENFORCED
) DISTRIBUTED BY (order_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all'
) as SELECT o.id as order_id,
           FROM_UNIXTIME(o.order_ts_raw) as ORDER_TS,
           o.total_amount as TOTAL,
           o.customer_name as CUSTOMER,
           s.id as SHIP_ID,
           FROM_UNIXTIME(s.ship_ts_raw) as SHIP_TS,
           s.warehouse,
           TIMESTAMPDIFF(HOUR,
             TO_TIMESTAMP(FROM_UNIXTIME(o.order_ts_raw)),                     -- convert numeric type (an epoch based timestamp in this case) to a formatted string in the default format of yyyy-MM-dd HH:mm:ss
             TO_TIMESTAMP(FROM_UNIXTIME(s.ship_ts_raw))) as HR_TO_SHIP
    FROM orders o inner join shipments s ON o.id = s.order_id
    AND TO_TIMESTAMP(FROM_UNIXTIME(s.ship_ts_raw))
     BETWEEN TO_TIMESTAMP(FROM_UNIXTIME(o.order_ts_raw))
     AND TO_TIMESTAMP(FROM_UNIXTIME(o.order_ts_raw))  + INTERVAL '7' DAY;
