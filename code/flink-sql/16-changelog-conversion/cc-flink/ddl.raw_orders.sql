-- Raw inbound orders topic carrying a custom CDC op code.
-- Every record is a plain append row; the change intent is expressed via the 'op' field:
--   'c'  = create  (INSERT)
--   'ub' = update-before (UPDATE_BEFORE)
--   'ua' = update-after  (UPDATE_AFTER)
--   'd'  = delete  (DELETE)
-- FROM_CHANGELOG reads this table and translates 'op' into Flink row kinds.
CREATE TABLE IF NOT EXISTS d16_raw_orders (
    order_id    INT,
    op          STRING,        -- custom op code; NOT a Flink system column
    user_id     STRING,
    product_id  STRING,
    quantity    INT,
    amount      DOUBLE

) DISTRIBUTED BY HASH(order_id) INTO 1 BUCKETS
WITH (
    'changelog.mode'        = 'append',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset',
    'scan.bounded.mode'     = 'unbounded'
);
