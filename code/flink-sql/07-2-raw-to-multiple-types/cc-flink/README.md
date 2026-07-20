# Confluent Cloud — Raw Value to Multiple Event Types

## Goal

Read multi-schema JSON (Confluent wire format) from `raw_account_events` via Flink `raw-value` metadata, strip the 5-byte prefix, parse with `JSON_VALUE`, and write the Avro-union `account_events` sink (same shape as 07-1).

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

## Test queries

```sql
-- JSON after wire-format prefix (magic + schema_id)
SELECT CAST(SUBSTRING(`raw_value` FROM 6) AS STRING) AS payload
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

See [../README.md](../README.md) for schema details and Schema Registry subjects.
