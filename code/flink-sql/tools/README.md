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

## Related

- [`cc_flink_rest_client.py`](cc_flink_rest_client.py) — lower-level `requests`-based REST client (legacy)
- [`cc_flink_deploy.py`](cc_flink_deploy.py) — confluent-sql based deploy library
