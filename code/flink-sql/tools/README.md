# Flink SQL development tools

A set of tools to help developing and deploying Flink SQL on Confluent Cloud, or CP Flink.

## Setup

```sh
cd code/flink-sql/tools
uv sync
```

## create_deploy_manifest

Each demo folder for cc deployment should include a `deploy_manifest.json` file to declare what to deploy. This file lists a set of group and then in each groups the name of the statement and file to match.

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

* It is possible to generate a manifest.json template from SQL files in a folder:

```sh
cd code/flink-sql/tools

# Preview without writing
uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../11-puzzles/my_demo --dry-run

# Write deploy_manifest.json
uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../11-puzzles/my_demo --prefix my-demo
```

Files are grouped by naming convention: `ddl.*` → ddl, `insert_*` / `dml.insert_*` → data, `dml.update_*` → scenario, other `dml.*` → pipeline.

--- 

## Deploy on Confluent Cloud

Deploy Flink SQL statement groups from demo folders using [confluent-sql](https://pypi.org/project/confluent-sql/) (REST API, no Confluent CLI).

* Set Confluent Cloud credentials and target env: `~/.confluent/.env` (override the file path with `CONFLUENT_ENV_FILE`).

| Variable | Purpose |
|----------|---------|
| `FLINK_API_KEY`, `FLINK_API_SECRET` | Or `CONFLUENT_CLOUD_API_KEY` / `SECRET` |
| `ORGANIZATION_ID` | Confluent org |
| `ENVIRONMENT_ID` | Environment / catalog (alias: `ENV_ID`) |
| `COMPUTE_POOL_ID` | Flink compute pool (alias: `CPOOLID`) |
| `DB_NAME` | Kafka cluster / `sql.current-database` |
| `CLOUD`, `REGION` | Or `FLINK_BASE_URL` |


- `deploy_all` — groups run in order for `deploy --group all`
- `undeploy_all` — groups whose statements are deleted first on full undeploy (streaming pipeline last)
- `drop_tables` — tables dropped in list order after statements are stopped (`DROP TABLE IF EXISTS`)
- `drop_statement_prefix` — optional prefix for ephemeral drop statements (default: derived from ddl names)
- `groups` — named lists of `{name, file}` (paths relative to demo folder)


### Deployment

```sh
cd code/flink-sql/tools

# Deploy everything in deploy_all
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update deploy --group all

# Single group
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update deploy --group ddl
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update undeploy --group pipeline

# Full teardown: stop/delete DML statements, then drop tables from manifest
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update undeploy --group all

# Statements only (skip drop_tables)
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update undeploy --group all --no-drop-tables

# Drop tables only
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update drop-tables
```

### Makefile shortcut

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

### Library API

The deployment tool is also a set of components within a python library that can be reused. Import from `cc_deploy` for custom scripts:

```python
from pathlib import Path
from cc_deploy import get_config, load_manifest, deploy_statements, full_undeploy

manifest = load_manifest(Path("deploy_manifest.json"))
deploy_statements(
    manifest.statements_for("ddl"),
    sql_dir=Path("."),
    config=get_config(),
    user_agent=manifest.user_agent,
)
full_undeploy(manifest, config=get_config())
```

### Custom groups

Any key under `groups` is deployable on its own. It does not need to appear in `deploy_all` unless you want it included in `make deploy` / `deploy --group all`.

Example from [04-joins/cc/deploy_manifest.json](../04-joins/cc/deploy_manifest.json): `op_ddl` deploys watermark-free DDL for the first tutorial step.

```sh
cd code/flink-sql/tools

# List groups defined in a manifest
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../04-joins/cc groups

# Deploy a custom group only
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../04-joins/cc deploy --group op_ddl
uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../04-joins/cc undeploy --group op_ddl
```

From a demo Makefile with `deploy-%` delegation (see [04-joins/Makefile](../04-joins/Makefile)):

```sh
cd code/flink-sql/04-joins
make deploy-op_ddl
```

Add a custom group to `undeploy_all` if its statements should be stopped during full teardown.

--- 



## Snapshot query

Run a bounded point-in-time query against an existing table. The confluent-sql driver
sets `sql.snapshot.mode = now` automatically in SNAPSHOT cursor mode.

```sh
cd code/flink-sql/tools

# Top 10 rows from a table
uv run python -m cc_deploy.run_snapshot_query --table orders --limit 10

# Filter and choose columns
uv run python -m cc_deploy.run_snapshot_query --table orders --columns "order_id, amount" --where "amount > 100"

# Custom SQL (count, joins, etc.)
uv run python -m cc_deploy.run_snapshot_query --sql "SELECT COUNT(*) AS cnt FROM orders" --output json
```

Library API:

```python
from cc_deploy import build_select_sql, run_snapshot_query

sql = build_select_sql("orders", limit=5)
result = run_snapshot_query(sql)
print(result.rowcount, result.rows)
```

--- 

## Streaming query

Run a continuous query and print rows as they arrive. Press Ctrl+C to stop.

```sh
cd code/flink-sql/tools

# Stream all rows from a table
uv run python -m cc_deploy.run_streaming_query --table orders

# Filter with custom SQL, stop after 20 rows
uv run python -m cc_deploy.run_streaming_query --sql "SELECT * FROM orders WHERE amount > 100" --max-rows 20
```

Library API:

```python
from cc_deploy import build_select_sql, run_streaming_query

sql = build_select_sql("orders", where="amount > 100")
stats = run_streaming_query(sql)  # prints rows until Ctrl+C
print(stats.rowcount)
```

---

## Table cleanup (Kafka topics → editable drop manifest)

List Kafka topics into a JSON file, edit which tables to drop, then run `DROP TABLE IF EXISTS` via confluent-sql.

**Step 1 — list topics** (Kafka env vars):

| Variable | Purpose |
|----------|---------|
| `KAFKA_BOOTSTRAP_SERVERS` | Broker list |
| `KAFKA_API_KEY`, `KAFKA_API_SECRET` | Confluent Cloud SASL (optional locally) |
| `KAFKA_SECURITY_PROTOCOL`, `KAFKA_SASL_MECHANISM` | Optional overrides |

```sh
cd code/flink-sql/tools

# Write drop_tables_manifest.json (user topics only; internals excluded)
uv run python -m cc_deploy.table_cleanup list --output drop_tables_manifest.json

# Preview without writing
uv run python -m cc_deploy.table_cleanup list --dry-run

# Include internal topics in manifest (still default drop: false)
uv run python -m cc_deploy.table_cleanup list --include-internal
```

**Step 2 — edit the manifest** — set `"drop": false` or remove rows for topics/tables to keep. Edit `"table"` if the Flink table name differs from the Kafka topic.

**Step 3 — drop tables** (Flink env vars, same as deploy):

```sh
# Dry-run: print DROP statements only
uv run python -m cc_deploy.table_cleanup drop --manifest drop_tables_manifest.json --dry-run

# Execute drops for entries with drop: true
uv run python -m cc_deploy.table_cleanup drop --manifest drop_tables_manifest.json
```

Stop running Flink statements first (`deploy_flink_statements undeploy`) if pipelines reference these tables.

Library API:

```python
from cc_deploy import (
    build_manifest_from_topics,
    drop_tables_by_name,
    get_config,
    list_kafka_topics,
    load_drop_tables_manifest,
    tables_to_drop,
)

topics = list_kafka_topics()
manifest = build_manifest_from_topics(topics, bootstrap_servers="...", database="my_db")
entries, raw = load_drop_tables_manifest(path)
drop_tables_by_name(tables_to_drop(entries), config=get_config())
```

---

## Register schema (Schema Registry)

Register a standalone Avro (`.avsc`) or JSON Schema (`.json`) under
RecordNameStrategy. Subject defaults:

| Type | Default subject |
|------|-----------------|
| AVRO | `namespace.name` from the file |
| JSON | `title` from the file |

Override with `--subject`. Type is inferred from the extension, or set with
`--type AVRO|JSON`.

Requires Schema Registry env vars in `~/.confluent/.env` (same as producers):

| Variable | Purpose |
|----------|---------|
| `SCHEMA_REGISTRY_ENDPOINT` | Registry URL |
| `SCHEMA_REGISTRY_API_KEY` / `SCHEMA_REGISTRY_API_SECRET` | Basic auth (Confluent Cloud) |

```sh
cd code/flink-sql/tools

uv run python -m cc_deploy.register_schema \
  ../07-1-multiple-event-types/python/schemas/DeviceCloseDetail.avsc

uv run python -m cc_deploy.register_schema path/to/schema.json
uv run python -m cc_deploy.register_schema path/to/schema.json --subject my.custom.Subject
uv run python -m cc_deploy.register_schema path/to/file.txt --type JSON --subject MyType
```

Example subject for `DeviceCloseDetail.avsc`:
`io.confluent.flink.multievent.DeviceCloseDetail`.

---

## Migrate Flink DML to dbt

Convert Flink `INSERT INTO ... SELECT` pipeline statements into dbt `streaming_table` models for [dbt-confluent](https://pypi.org/project/dbt-confluent/), convert DDL to schema. Column types and table options are taken from the paired DDL file.

[See dedicated readme](./flink_dbt_migrate/README.md)



