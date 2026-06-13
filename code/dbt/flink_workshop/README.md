# Flink workshop — CRM data product (dbt-confluent)

Deploys the [Jan Svoboda's Flink SQL workshop](https://github.com/griga23/flink-workshop) CRM exercises as one dbt project on Confluent Cloud for Flink. All models use the `crm` tag and live under `models/crm/`.

## Prerequisites

1. From `code/dbt/`: `uv sync`
2. `~/.dbt/profiles.yml` with `cc_flink` ([docs/coding/dbt.md](../../docs/coding/dbt.md))
3. Credentials:

   ```bash
   export CONFLUENT_FLINK_API_KEY=...
   export CONFLUENT_FLINK_API_SECRET=...
   ```

## One-shot deploy

```bash
cd code/dbt/flink_workshop
make debug
make run-full    # first time or recreate tables/topics
```

Incremental deploy (no topic drop):

```bash
make run
```

Equivalent:

```bash
cd code/dbt
uv run dbt run --project-dir flink_workshop --profiles-dir ~/.dbt --select tag:crm --full-refresh
```

dbt builds in dependency order: Faker sources → `customers_pk` → joins and metrics (and MongoDB models when enabled).

## Project layout

| Layer | Models | Role |
|-------|--------|------|
| `sources/` | `transactions_faker`, `customers_faker` | Faker test data |
| `sources/` | `mongodb_movies` | MongoDB `sample_mflix.movies` (optional) |
| `dimensions/` | `customers_pk` | PK customer dimension (upsert) |
| `marts/joins/` | `txn_customer_temporal` | Temporal join to `customers_pk` |
| `marts/joins/` | `txn_customer_interval` | 10s interval join |
| `marts/joins/` | `txn_customer_equi` | Equi-join (high state, no TTL) |
| `marts/joins/` | `txn_customer_equi_ttl` | Equi-join with `sql.state-ttl` |
| `marts/joins/` | `customer_movies_lookup` | KEY_SEARCH_AGG lookup (optional) |
| `marts/metrics/` | `withdrawals_by_account` | Global GROUP BY + HAVING |
| `marts/metrics/` | `withdrawal_running_totals` | OVER running sum |
| `marts/metrics/` | `failed_payments_tumble_1m` | TUMBLE 1 minute |
| `marts/metrics/` | `merchant_session_counts` | SESSION 5 second gap |
| `marts/metrics/` | `failed_payments_over_1m` | OVER 1 minute |
| `marts/metrics/` | `successful_payments_tumble_lag` | TUMBLE + LAG |

## dbt patterns used

### Materializations

- `streaming_source` — Faker (and optional MongoDB) connector tables
- `streaming_table` — continuous `CREATE TABLE` + `INSERT INTO ... SELECT` pipelines

### Statement names

Set `statement_name` in `config()` so statements are easy to find in the Flink UI (e.g. `fw_crm_customers_pk`). Unnamed models default to `{statement_name_prefix}{project}-{model}` from `profiles.yml`.

### Stateful joins

`txn_customer_equi_ttl` sets TTL via `pre_hook`:

```sql
SET 'sql.state-ttl' = '{{ var('crm_state_ttl') }}'  -- default 2d in dbt_project.yml
```

Compare with `txn_customer_equi` (no TTL) using `EXPLAIN` in the SQL workspace.

### EXPLAIN (manual)

dbt does not submit `EXPLAIN`. Copy SQL from a model or from `analyses/` and prefix with `EXPLAIN` in the Flink workspace.

### Full refresh

`streaming_source` and `streaming_table` need `--full-refresh` to replace existing relations. That drops Kafka topics for pipeline tables such as `customers_pk`. Use `make run-full` for workshop resets.

## Optional MongoDB lookup

Lookup join models are disabled by default (`crm_enable_mongodb: false`).

1. Provision Atlas with `sample_mflix` and allow your Flink egress IP.
2. Export:

   ```bash
   export CRM_MONGODB_ENDPOINT='mongodb+srv://....mongodb.net/'
   export CRM_MONGODB_USERNAME=...
   export CRM_MONGODB_PASSWORD=...
   ```

3. Deploy with MongoDB enabled:

   ```bash
   cd code/dbt
   uv run dbt run --project-dir flink_workshop --profiles-dir ~/.dbt \
     --select tag:crm \
     --vars '{"crm_enable_mongodb": true}' \
     --full-refresh
   ```

This runs `crm_create_mongodb_connection()`, creates `mongodb_movies`, and starts `customer_movies_lookup`.

## Selective deploy

```bash
# Sources and dimension only
dbt run --select path:models/crm/sources path:models/crm/dimensions --project-dir flink_workshop

# Joins only (requires upstream tables)
dbt run --select path:models/crm/marts/joins --project-dir flink_workshop

# Single pipeline
dbt run --select txn_customer_temporal --project-dir flink_workshop
```

## Manual verification

```sql
SELECT * FROM transactions_faker LIMIT 10;
SELECT * FROM customers_pk;              -- Changelog view for upsert
SELECT * FROM txn_customer_temporal LIMIT 10;
SELECT * FROM failed_payments_tumble_1m LIMIT 10;
```

Tumble metrics emit after the first window closes (about one minute).

## Workshop gaps

- `DISTRIBUTED BY` / bucket count from Faker DDL is not emitted (dbt-confluent `streaming_source` limitation).
- `customers_pk` ALTER steps (metadata columns, read-uncommitted) run as `post_hook` on deploy.

## Drop and redeploy

Full teardown (stop Flink statements, then drop tables). Uses [cc_deploy/flink_deploy.py](../../flink-sql/tools/cc_deploy/flink_deploy.py) via `scripts/drop_crm.py` and `teardown_manifest.json`. Credentials: `~/.confluent/.env` (or `CONFLUENT_ENV_FILE`).

```bash
make teardown      # stop statements + drop tables
make drop-tables   # drop only (statements still running)
make undeploy      # delete statements only
make run-full      # redeploy
```

Direct CLI:

```bash
cd code/flink-sql/tools
uv run python ../../dbt/flink_workshop/scripts/drop_crm.py teardown
```

When adding a CRM model, update `teardown_manifest.json`: append its `statement_name` to the matching `groups` entry and its table name to `drop_tables` (dependents before sources).

## Related

- [code/dbt/README.md](../README.md)
- [airbnb_streaming](../airbnb_streaming/)
