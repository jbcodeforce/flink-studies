# Confluent Cloud — Raw Value to Multiple Event Types

## Goal

Read plain JSON from `raw_account_events` via Flink `raw-value` metadata, parse with `JSON_VALUE`, and write the Avro-union `account_events` sink (same shape as 07-1).

## Deploy order

```sh
make sync
make deploy-ddl
make deploy-pipeline
```

## Produce test data

```sh
cd ../python
uv sync
source ../../set_env.sh
uv run producers/produce_raw_account_events.py
```

## Test queries

```sql
SHOW CREATE TABLE raw_account_events;
```

Results look like:
```sql
CREATE TABLE `j9r-env`.`j9r-kafka`.`raw_account_events` (
  `val` VARBINARY(2147483647),
  `raw_value` VARBINARY(2147483647) METADATA FROM 'raw-value' VIRTUAL
)
DISTRIBUTED INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'connector' = 'confluent',
  'kafka.cleanup-policy' = 'delete',
  'kafka.compaction.time' = '0 ms',
  'kafka.max-message-size' = '2097164 bytes',
  'kafka.message-timestamp-type' = 'create-time',
  'kafka.retention.size' = '0 bytes',
  'kafka.retention.time' = '0 ms',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw'
)
```

```sql
SHOW CREATE TABLE account_events;
```

Result is:
```sql
CREATE TABLE `j9r-env`.`j9r-kafka`.`account_events` (
  `correlationId` VARCHAR(2147483647) NOT NULL,
  `contextInfo` ROW<`eventName` VARCHAR(2147483647), `correlationId` VARCHAR(2147483647), `sourceSystem` VARCHAR(2147483647)>,
  `eventDetail` ROW<`DeviceSwapDetail` ROW<`accountId` VARCHAR(2147483647), `deviceId` VARCHAR(2147483647)>, `SubscriptionDetail` ROW<`accountId` VARCHAR(2147483647), `status` VARCHAR(2147483647), `planId` VARCHAR(2147483647)>, `DeviceCloseDetail` ROW<`accountId` VARCHAR(2147483647), `reasonCode` VARCHAR(2147483647)>>,
  CONSTRAINT `PK_correlationId` PRIMARY KEY (`correlationId`) NOT ENFORCED
)
DISTRIBUTED BY HASH(`correlationId`) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'connector' = 'confluent',
  'kafka.cleanup-policy' = 'delete',
  'kafka.compaction.time' = '0 ms',
  'kafka.max-message-size' = '2097164 bytes',
  'kafka.message-timestamp-type' = 'create-time',
  'kafka.retention.size' = '0 bytes',
  'kafka.retention.time' = '0 ms',
  'key.format' = 'avro-registry',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'avro-registry'
)
```

```sql
SELECT * FROM account_events
WHERE eventDetail.DeviceSwapDetail IS NOT NULL;

SELECT * FROM account_events
WHERE eventDetail.SubscriptionDetail IS NOT NULL;

SELECT * FROM account_events
WHERE eventDetail.DeviceCloseDetail IS NOT NULL;
```

## Undeploy

```sh
make undeploy-pipeline
make drop-tables
```

See [../README.md](../README.md) for schema details.
