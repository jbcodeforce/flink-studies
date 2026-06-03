# Confluent Cloud Flink SQL deploy tools

Deploy SQL statement groups from demo folders using [confluent-sql](https://pypi.org/project/confluent-sql/) (REST API, no Confluent CLI).

## Setup

```sh
cd code/flink-sql/tools
uv sync
```

Credentials and target env: `~/.confluent/.env` (override with `CONFLUENT_ENV_FILE`).

| Variable | Purpose |
|----------|---------|
| `FLINK_API_KEY`, `FLINK_API_SECRET` | Or `CONFLUENT_CLOUD_API_KEY` / `SECRET` |
| `ORGANIZATION_ID` | Confluent org |
| `ENVIRONMENT_ID` | Environment / catalog (alias: `ENV_ID`) |
| `COMPUTE_POOL_ID` | Flink compute pool (alias: `CPOOLID`) |
| `DB_NAME` | Kafka cluster / `sql.current-database` |
| `CLOUD`, `REGION` | Or `FLINK_BASE_URL` |

## Demo manifest

Each demo folder includes `deploy_manifest.json`:

```json
{
  "user_agent": "flink-studies-my-demo/0.1",
  "deploy_all": ["ddl", "pipeline", "data"],
  "undeploy_all": ["scenario", "data", "pipeline"],
  "drop_tables": ["enriched_orders", "orders", "products"],
  "drop_statement_prefix": "my-demo-drop",
  "groups": {
    "ddl": [
      {"name": "my-demo-ddl-orders", "file": "ddl.orders.sql"}
    ],
    "pipeline": [],
    "data": []
  }
}
```

- `deploy_all` — groups run in order for `deploy --group all`
- `undeploy_all` — groups whose statements are deleted first on full undeploy (streaming pipeline last)
- `drop_tables` — tables dropped in list order after statements are stopped (`DROP TABLE IF EXISTS`)
- `drop_statement_prefix` — optional prefix for ephemeral drop statements (default: derived from ddl names)
- `groups` — named lists of `{name, file}` (paths relative to demo folder)

## CLI

```sh
cd code/flink-sql/tools

# Deploy everything in deploy_all
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update deploy --group all

# Single group
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update deploy --group ddl
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update undeploy --group pipeline

# Full teardown: stop/delete DML statements, then drop tables from manifest
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update undeploy --group all

# Statements only (skip drop_tables)
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update undeploy --group all --no-drop-tables

# Drop tables only
uv run python deploy_flink_statements.py --sql-dir ../11-puzzles/cart_update drop-tables
```

## Makefile shortcut

From a demo folder (example: cart_update):

```sh
make sync          # once, installs tools deps
make deploy-ddl
make deploy-pipeline
make deploy-data
make undeploy      # stop DML + drop all tables
make drop-tables   # drop tables only
```

Demo Makefiles delegate to `tools/Makefile` with `SQL_DIR` set to the demo path.

## Library API

Import from `cc_flink_deploy` for custom scripts:

```python
from pathlib import Path
from cc_flink_deploy import get_config, load_manifest, deploy_statements, full_undeploy

manifest = load_manifest(Path("deploy_manifest.json"))
deploy_statements(
    manifest.statements_for("ddl"),
    sql_dir=Path("."),
    config=get_config(),
    user_agent=manifest.user_agent,
)
full_undeploy(manifest, config=get_config())
```

## Snapshot query

Run a bounded point-in-time query against an existing table. The confluent-sql driver
sets `sql.snapshot.mode = now` automatically in SNAPSHOT cursor mode.

```sh
cd code/flink-sql/tools

# Top 10 rows from a table
uv run python run_snapshot_query.py --table orders --limit 10

# Filter and choose columns
uv run python run_snapshot_query.py --table orders --columns "order_id, amount" --where "amount > 100"

# Custom SQL (count, joins, etc.)
uv run python run_snapshot_query.py --sql "SELECT COUNT(*) AS cnt FROM orders" --output json
```

Library API:

```python
from cc_flink_deploy import build_select_sql, run_snapshot_query

sql = build_select_sql("orders", limit=5)
result = run_snapshot_query(sql)
print(result.rowcount, result.rows)
```

## Streaming query

Run a continuous query and print rows as they arrive. Press Ctrl+C to stop.

```sh
cd code/flink-sql/tools

# Stream all rows from a table
uv run python run_streaming_query.py --table orders

# Filter with custom SQL, stop after 20 rows
uv run python run_streaming_query.py --sql "SELECT * FROM orders WHERE amount > 100" --max-rows 20
```

Library API:

```python
from cc_flink_deploy import build_select_sql, run_streaming_query

sql = build_select_sql("orders", where="amount > 100")
stats = run_streaming_query(sql)  # prints rows until Ctrl+C
print(stats.rowcount)
```

## Migrate Flink DML to dbt

Convert Flink `INSERT INTO ... SELECT` pipeline statements into dbt `streaming_table` models for [dbt-confluent](https://pypi.org/project/dbt-confluent/). Column types and table options are taken from the paired DDL file.

```sh
cd code/flink-sql/tools

# Dry-run (prints model SQL + schema.yml to stdout)
uv run python migrate_dml_to_dbt.py \
  ../10-windowing/tumble_then_hop_rolling/dml.rolling_features.sql \
  ../../dbt/airbnb_streaming/models/intermediates/

# Write files
uv run python migrate_dml_to_dbt.py \
  ../11-puzzles/cart_update/dml.build_cart_line_items.sql \
  ../../dbt/airbnb_streaming/models/intermediates/ \
  --write

# Override DDL discovery or ref() mapping
uv run python migrate_dml_to_dbt.py \
  ../10-windowing/tumble_then_hop_rolling/dml.rolling_features.sql \
  ../../dbt/airbnb_streaming/models/intermediates/ \
  --ddl-file ../10-windowing/tumble_then_hop_rolling/ddl.rolling_features.sql \
  --ref-table events=src_events \
  --write
```

DDL auto-discovery (override with `--ddl-file`):

1. `dml.{stem}.sql` → sibling `ddl.{stem}.sql`
2. Else `ddl.{target_table}.sql` in the same folder

Outputs:

- `{model_name}.sql` — `{{ config(materialized='streaming_table', with={...}) }}` plus SELECT body (no `INSERT INTO`)
- `schema.yml` — merged model entry with `columns[].data_type` from DDL

Upstream tables in `FROM` / `JOIN` are rewritten to `{{ ref('table') }}` automatically (CTE names are skipped). Downstream `dbt run` still requires those upstream tables to exist as other dbt models or `sources.yaml` entries.

Limitations (v1): `INSERT INTO ... VALUES` and CTAS are not supported; batch migration from `deploy_manifest.json` is one file per invocation.

Entry point: `flink-sql-migrate-dbt` (when the tools package is installed with entry points).

## Related

- [`cc_flink_rest_client.py`](cc_flink_rest_client.py) — lower-level `requests`-based REST client (legacy)
- [`cc_flink_deploy.py`](cc_flink_deploy.py) — deploy, undeploy, snapshot, and streaming query library
- [`run_snapshot_query.py`](run_snapshot_query.py) — snapshot query CLI
- [`run_streaming_query.py`](run_streaming_query.py) — streaming query CLI
