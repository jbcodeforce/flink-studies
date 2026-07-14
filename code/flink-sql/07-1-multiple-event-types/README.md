# Demonstrate Multiple Event Types in Confluent Cloud for Apache Flink

Illustrates the [Handle Multiple Event Types](https://docs.confluent.io/cloud/current/flink/how-to-guides/multiple-event-types.html?category=avro) how-to using an **Avro union** on a single envelope field.

Domain: a generic **account lifecycle** stream. One topic carries three event subtypes behind a shared context.

## Schema shape

Topic: `account_events` (append, Avro / TopicNameStrategy).

| Record | Fields |
| --- | --- |
| `AccountLifecycleEvent` | `contextInfo`, `eventDetail` |
| `EventContext` | `eventName`, `correlationId`, `sourceSystem` |
| `DeviceSwapDetail` | `accountId`, `deviceId` |
| `SubscriptionDetail` | `accountId`, `status`, `planId` |
| `DeviceCloseDetail` | `accountId`, `reasonCode` |

`eventDetail` is an Avro **union** of the three detail records (not an array). Flink maps that union to a `ROW` with one non-null branch per message.

Avro schemas: [python/schemas/](python/schemas/).

## Layout

| Path | Purpose |
| --- | --- |
| [cc-flink/](cc-flink/) | Confluent Cloud Flink SQL (DDL, seed DML, deploy manifest) |
| [python/](python/) | Kafka Avro producer for `account_events` |

## Quick start (Confluent Cloud)

```sh
cd cc-flink
make sync
make deploy-ddl
make deploy-data
```

## Produce more events

```sh
cd python
uv sync
source ../../set_env.sh
uv run producers/produce_account_events.py
```

## Inspect the inferred table

```sql
SHOW CREATE TABLE account_events;
```

Expect `eventDetail` as a `ROW` of three named branches, for example:

```sql
-- DeviceSwap events
SELECT
  contextInfo.eventName,
  eventDetail.DeviceSwapDetail.*
FROM account_events
WHERE eventDetail.DeviceSwapDetail IS NOT NULL;

-- Subscription events
SELECT
  contextInfo.eventName,
  eventDetail.SubscriptionDetail.*
FROM account_events
WHERE eventDetail.SubscriptionDetail IS NOT NULL;

-- DeviceClose events
SELECT
  contextInfo.eventName,
  eventDetail.DeviceCloseDetail.*
FROM account_events
WHERE eventDetail.DeviceCloseDetail IS NOT NULL;
```

See the expected results

![](../docs/071-results.png)

## Undeploy

```sh
cd cc
make undeploy-data
make drop-tables
```
