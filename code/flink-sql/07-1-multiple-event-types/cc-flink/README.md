# Confluent Cloud — Multiple Event Types

## Goal

Demonstrate Avro union `eventDetail` (DeviceSwap / Subscription / DeviceClose) on topic `account_events` and filter each branch in Flink SQL.

## Deploy order

```sh
make sync
make deploy-ddl
make deploy-data
```

## Produce test data (alternative to INSERT)

```sh
cd ../python
uv sync
source ../../set_env.sh
uv run producers/produce_account_events.py
```

## Test queries

```sql
SHOW CREATE TABLE account_events;

SELECT * FROM account_events
WHERE eventDetail.DeviceSwapDetail IS NOT NULL;

SELECT * FROM account_events
WHERE eventDetail.SubscriptionDetail IS NOT NULL;

SELECT * FROM account_events
WHERE eventDetail.DeviceCloseDetail IS NOT NULL;
```

See the expected results

![](../docs/071-results.png)

## Undeploy

```sh
make undeploy-data
make drop-tables
```

See [../README.md](../README.md) for schema details.
