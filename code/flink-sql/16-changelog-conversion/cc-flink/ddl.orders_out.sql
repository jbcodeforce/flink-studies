-- Outbound topic for downstream consumers that don't understand Flink's internal
-- row kinds (-U / +U).  TO_CHANGELOG converts d16_orders back into a plain
-- append stream and stamps each row with an explicit 'op' field:
--   'c' = create  (was INSERT)
--   'u' = update  (was UPDATE_AFTER)
--   'd' = delete  (was DELETE)
-- A microservice, Connect sink, or non-Flink consumer can act on 'op' directly.
CREATE TABLE IF NOT EXISTS d16_orders_out (
    order_id    INT,
    user_id     STRING,
    product_id  STRING,
    op          STRING          -- op code stamped by TO_CHANGELOG
) DISTRIBUTED BY HASH(order_id) INTO 1 BUCKETS
WITH (
    'changelog.mode'        = 'append',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset',
    'scan.bounded.mode'     = 'unbounded'
);
