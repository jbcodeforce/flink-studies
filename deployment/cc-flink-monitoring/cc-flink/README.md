# Monitoring demo: users, transactions, monthly totals

Flink SQL statements that generate traffic for the [cc-flink-monitoring](../README.md) Grafana dashboard and populate 30-day TUMBLE windows with realistic history.

## Pipeline

1. **users_faker** (bounded, 100 rows, `user_001`–`user_100`) → **users** Kafka table
2. **Python producer** → **`raw_transactions`** Kafka topic (~73,000 rows by default)  
   ~2 transactions per user per day; `ts` progresses monotonically across the last 365 days
3. **raw_transactions** → **transactions** (Flink streaming insert)
4. **transactions** → **user_monthly_totals** (TUMBLE 30 days, upsert)

The transaction load runs at 100 rows/s by default (~12 minutes). Start **user_monthly_totals** before or during the load; it reads from `earliest-offset`.

## Prerequisites

`~/.confluent/.env` (or `CONFLUENT_ENV_FILE`) with:

- `FLINK_API_KEY` / `FLINK_API_SECRET`
- `ORGANIZATION_ID`, `ENVIRONMENT_ID`
- `FLINK_COMPUTE_POOL_ID` — pool used for all statements
- `FLINK_DATABASE_NAME` — Kafka cluster database (e.g. `j9r-kafka`)

## Deploy

```bash
make sync    # once: install tools venv
make deploy  # ddl → load users faker → monthly rollup
```

## Produce transactions

Install the producer dependencies once:

```bash
python3 -m pip install "confluent-kafka[avro,schemaregistry]>=2.4.0" python-dotenv authlib
```

Ensure `~/.confluent/.env` includes Kafka and Schema Registry settings:

- `KAFKA_BOOTSTRAP_SERVERS` (or `BOOTSTRAP_SERVERS`)
- `KAFKA_API_KEY` / `KAFKA_API_SECRET`
- `SCHEMA_REGISTRY_ENDPOINT` / `SCHEMA_REGISTRY_API_KEY` / `SCHEMA_REGISTRY_API_SECRET`

Then run (creates the `raw_transactions` topic if missing):

```bash
make produce-transactions
```

For the Flink pipeline to consume the topic, deploy DDL first:

```bash
make deploy-ddl
make deploy-pipeline
```

Override the env file path with `CONFLUENT_ENV_FILE=/path/to/.env` if needed.

## Statement names (Grafana / Prometheus)

| Statement | Role |
|-----------|------|
| `monitoring-dml-user-monthly-totals` | 30-day amount per user aggregation (RUNNING) |
| `monitoring-dml-load-users` | One-shot user seed (COMPLETED) |

Filter in Grafana **Statement(s)** variable or Prometheus:

```promql
confluent_flink_statement_status{flink_statement_name=~"monitoring-dml-.*"}
```

## Teardown

```bash
make undeploy
```

Stops streaming statements, deletes statement resources, and drops Kafka tables listed in `deploy_manifest.json`.

## Files

| File | Purpose |
|------|---------|
| `ddl.users.sql` | Kafka sink for users |
| `ddl.raw_transactions.sql` | Kafka source table for the Python producer |
| `ddl.transactions.sql` | Kafka table for normalized transactions (event time on `ts`) |
| `ddl.user_monthly_totals.sql` | Kafka sink for monthly aggregates |
| `ddl.users_faker.sql` | Faker source, 100 users |
| `dml.load_users.sql` | Seed users from faker |
| `producer/transactions_producer.py` | Produces 1-year history to `raw_transactions` |
| `dml.transactions.sql` | Stream insert from `raw_transactions` to `transactions` |
| `dml.user_monthly_totals.sql` | 30-day rollup into sink |

## Tuning row volume

`73000` = `100 users × 365 days × 2 tx/day`. Tune volume with producer flags `--users`, `--days`, and `--tx-per-user-per-day`.

## Watermarks and idle sources

The `transactions` table declares event time on `ts` and sets `scan.watermark.idle-timeout = '1 min'` so idle Kafka partitions do not block watermark advancement after the bounded history load completes.

After the Python producer finishes, the source has no new records. Without an idle timeout, Flink can leave the exported watermark at `Long.MIN_VALUE`, which Grafana (before filtering) displayed as hundreds of millions of years of lag. See [monitoring README — Watermark lag](../README.md#watermark-lag-findings-and-interpretation).

If you change `ddl.transactions.sql`, recreate the table:

```bash
make undeploy
make deploy
```
