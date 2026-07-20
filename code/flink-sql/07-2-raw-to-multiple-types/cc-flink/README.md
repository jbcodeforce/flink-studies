# Confluent Cloud — Raw Value to Multiple Event Types

## Goal

Read multi-schema JSON (Confluent wire format) from `raw_account_events` via Flink `raw-value` metadata, strip the 5-byte prefix, parse with `JSON_VALUE`, and write the Avro-union `account_events` sink (same shape as 07-1).

Source producers register three incompatible JSON schemas as versions of **`raw_account_events-value`** (TopicNameStrategy, compatibility **NONE**) and pin `use.schema.id` per event type.

## Deploy order

```sh
make sync
make deploy-ddl
make deploy-pipeline
```

Redeploy the transform after DML changes:

```sh
make undeploy-pipeline
make deploy-pipeline
```

## Produce / consume test data

```sh
cd ../python
uv sync
source ../../set_env.sh
uv run producers/produce_raw_account_events.py
uv run consumers/consume_raw_account_events.py --from-beginning --max-messages 3
```

Expect three distinct `schema_id` values in the consumer output (one per event type).

## Test queries

```sql
-- JSON after wire-format prefix (magic + schema_id)
SELECT SUBSTRING(CAST(`val` AS STRING), 6) AS payload
FROM raw_account_events
LIMIT 10;

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

Clean Kafka topic + Schema Registry (from `../python`):

```sh
cd ../python
source ../../set_env.sh
uv run cleanup_schema_registry.py
uv run cleanup_schema_registry.py --include-sink   # optional: account_events topic + subjects
```

See [../README.md](../README.md) for Schema Registry subject / NONE details.
