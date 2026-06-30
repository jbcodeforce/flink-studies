# Car Rides — Confluent Cloud

## Goal

Deploy Flink SQL on Confluent Cloud for the `raw_rides` stream and downstream processing.

## Status

Scaffold — ready for customization. DDL and pipeline stubs follow CC Flink SQL conventions.

## Implementation approach

- Flink SQL files in this folder (`ddl.*.sql`, `dml.*.sql`)
- Deployment via [code/flink-sql/tools](../../../code/flink-sql/tools/) (`deploy_manifest.json` + `make deploy-*`)

## Prerequisites

- Confluent Cloud environment with Flink compute pool
- Credentials in `~/.confluent/.env` (see tools README)

## How to run

```bash
make sync
make deploy-ddl
make deploy-pipeline

# Teardown
make undeploy
make drop-tables
```

## Test queries

After deploying and producing data:

```sql
SELECT * FROM driver customer ride trip_metrics daily_revenue LIMIT 10;
```

## Troubleshooting

See [assistants/jump_start_demo/reference/confluent-flink-sql.md](../../../assistants/jump_start_demo/reference/confluent-flink-sql.md).
