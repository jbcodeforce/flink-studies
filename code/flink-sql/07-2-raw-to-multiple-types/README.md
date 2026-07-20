# Process raw JSON into a multiple-event-types Avro sink

Based on [07-1-multiple-event-types](../07-1-multiple-event-types/README.md), but for the case where the producer **cannot** adopt the Avro envelope / Schema Registry shape,  this demo reads the Kafka payload via Flink [`raw-value` metadata](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#raw-value), parses it as JSON with `JSON_VALUE`, and writes the typed union sink.

Domain: the same **account lifecycle** events as 07-1 (DeviceSwap, Subscription, DeviceClose).

## Approach

![](./docs/approach.drawio.png)

Do not run 07-1 and 07-2 at the same time: both use the sink topic `account_events`.

## Source JSON shape

Topic: `raw_account_events` (plain UTF-8 JSON, no Confluent wire-format schema ID).

```json
{
  "contextInfo": {
    "eventName": "DeviceSwap",
    "correlationId": "corr-…",
    "sourceSystem": "billing-system"
  },
  "eventDetail": { "accountId": "acc-001", "deviceId": "dev-99" }
}
```

`eventDetail` fields vary by `eventName`:

| eventName | eventDetail fields |
| --- | --- |
| `DeviceSwap` | `accountId`, `deviceId` |
| `Subscription` | `accountId`, `status`, `planId` |
| `DeviceClose` | `accountId`, `reasonCode` |

## Sink schema

Topic: `account_events` — same Avro union envelope as 07-1 (`contextInfo` + `eventDetail` as a ROW of three named branches). See [07-1 schemas](../07-1-multiple-event-types/python/schemas/).

## Layout

| Path | Purpose |
| --- | --- |
| [cc-flink/](cc-flink/) | Confluent Cloud Flink SQL (DDL, transform DML, deploy manifest) |
| [python/](python/) | Plain JSON producer for `raw_account_events` |

## Quick start (Confluent Cloud)

```sh
cd cc-flink
make sync
make deploy-ddl
make deploy-pipeline
```

## Produce raw events

```sh
cd python
uv sync
source ../../set_env.sh
uv run producers/produce_raw_account_events.py
```

The producer uses `KafkaJSONProducer(..., use_schema_registry=False)` so values are plain JSON bytes.

## Inspect


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
-- Peek at the raw payload string
SELECT CAST(`raw_value` AS STRING) AS payload
FROM raw_account_events
LIMIT 10;

-- Typed sink branches (same filters as 07-1)
SELECT
  contextInfo.eventName,
  eventDetail.DeviceSwapDetail.*
FROM account_events
WHERE eventDetail.DeviceSwapDetail IS NOT NULL;

SELECT
  contextInfo.eventName,
  eventDetail.SubscriptionDetail.*
FROM account_events
WHERE eventDetail.SubscriptionDetail IS NOT NULL;

SELECT
  contextInfo.eventName,
  eventDetail.DeviceCloseDetail.*
FROM account_events
WHERE eventDetail.DeviceCloseDetail IS NOT NULL;
```

## Undeploy

```sh
cd cc-flink
make undeploy-pipeline
make drop-tables
```
