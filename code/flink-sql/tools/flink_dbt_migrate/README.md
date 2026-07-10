#  Migrate Flink DML to dbt

## Problem Statement

The classical use case for Confluent Cloud fo Flink development is to start doing Flink SQL using the Confluent Workspace, using incremental complexity, and when satisfied, save the SQL query to a file within a git repository. 
Adopting dbt means developers need to refactor this Flink SQL into dbt templating syntax, update yaml files and test the translation using `dbt`. This is error prone, and more work for the Flink developers. 

## Goals

* Taking one or more Flink SQL queries in the form of ddl, dml or ctas and transform them for dbt processing
* Create schema.yaml definition from DDLs 
* As in 2026, any developers are using AI, it may ne relevant to add some skill and tools or even agent to automate as much as possible this migration. 

## Requirements 

* [x] Expose as cli command: flink_dbt_migrate.migrate_dml_to_dbt
* [x] Dry-run (prints model SQL + schema.yml to stdout)
* [ ] 

## Implementation Approach

Use a CLI

## Usage

```sh
cd code/flink-sql/tools

# Dry-run (prints model SQL + schema.yml to stdout)
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt \
  ../10-windowing/tumble_then_hop_rolling/dml.rolling_features.sql \
  ../../dbt/staging/models/intermediates/rolling_features

# Write files
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt \
  ../11-puzzles/cart_update/dml.build_cart_line_items.sql \
  ../../dbt/airbnb_streaming/models/intermediates/ \
  --write

# Override DDL discovery or ref() mapping
uv run python  -m flink_dbt_migrate.migrate_dml_to_dbt \
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