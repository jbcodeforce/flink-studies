-- DDL for order-simple table
-- Based on simple.json schema structure with OrderDetails container

CREATE TABLE `order-simple` (
  OrderDetails ROW<
    OrderId BIGINT,
    Status STRING,
    Equipment ARRAY<ROW<
      ModelCode STRING,
      Rate STRING
    >>,
    TotalPaid DOUBLE
  >
) WITH (
  'connector' = 'kafka',
  'topic' = 'order-simple',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'key.avro-registry.schema-context' = '.dev',
  'value.avro-registry.schema-context' = '.dev',
  'scan.startup.mode' = 'earliest-offset',
  'kafka.cleanup-policy' = 'delete',
  'value.fields-include' = 'all'
);
