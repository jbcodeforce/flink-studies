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
SHOW CREATE TABLE account_events;

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
