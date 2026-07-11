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
* [x] Specify ddl as parameter and extract schema definition to generate schema.yaml
* [x] Infer schema from DML or existing ddl file in the same folder with the same name as the dml
* [x] Derive model name from table name within the dml, support defining it as part of the cli parameter
* [x] Define a schema.yaml per model. This is a recommended best practice to keep the configuration files modular to avoid searching through one giant file
* [x] Default materialization as streaming-table, but support  defining it as part of the cli parameter
* [x] Support optional checking if schema or model will be changed from existing ones. Stop if this is the case
* [x] Support forcing overwrite for model and schema
* [x] Support searching for parents from CTEs, joins, from, windows table.. as sources or references. Search in the root source flink directory. It will create and update sources.yaml
* [ ] Validate the created Flink SQL after dbt compile to compare with source DML
* [ ] Migrate full simple project: https://github.com/jbcodeforce/flink_project_demos/tree/main/customer_360/c360_flink_processing

## Implementation Approach

* The migration tool is exposed as a CLI (Typer-based):
  ```sh
  python -m flink_dbt_migrate.migrate_dml_to_dbt [OPTIONS] DML_PATH TARGET_PATH
  ```

  Positional Arguments

  - `DML_PATH`: Path to the source Flink DML SQL file (e.g., `dml.rolling_features.sql`).
  - `TARGET_PATH`: Path for the generated model and schema files, or a directory (if `--write` is used).

  Options

  - `--ddl-path`, `-d`  Path to a DDL file (`ddl.<table>.sql`) for full schema information. If not set, will attempt to infer schema from DML or existing ddl. file in the same folder with the same name as the dml
  - `--write`, `-w`  Write output files (`.sql`, `schema.yml`) to `TARGET_PATH`. If omitted, prints model SQL and YAML to stdout (dry-run).
  - `--ref-overrides`  Comma-separated mapping for table names to dbt refs.  
      Format: `original1:override1,original2:override2`  
      Useful for renaming sources or intermediate tables in dbt.
  - `--help`  Show usage and options.


## Usage

### Methodology

1. Create a dbt project: `dbt init cc_dbt` for example under 04-joins
1. Modify the `~/.dbt/profile.yaml` to add Confluent Cloud environment, kafka_cluster, and all other settings...
  ```yaml
  cc_flink:
    outputs:
      dev:
        cloud_provider: 
        cloud_region: 
        compute_pool_id: lfcp-
        dbname: j9r-kafka
        environment_id: env-
        execution_mode: streaming_query
        flink_api_key: '{{ env_var(''CONFLUENT_FLINK_API_KEY'') }}'
        flink_api_secret: '{{ env_var(''CONFLUENT_FLINK_API_SECRET'') }}'
        organization_id: 4....
        statement_label: dbt-confluent
        statement_name_prefix: dbt-
        threads: 1
        type: confluent
    target: dev
  ```

1. Define API key and secret  as environment variables
  ```sh
  export CONFLUENT_FLINK_API_KEY=...
  export CONFLUENT_FLINK_API_SECRET=...
  ```

1. In the created `dbt-project.yaml` modify the profile reference to point to the Confluent Cloud connection information: `profile: 'cc_flink'`
1. Clean the models folder: `rm -r models/examples`


### Commmands

Under `code/flink-sql/tools`

```sh
# Dry-run
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt ../04-joins/cc-flink/dml.enriched_orders.sql ../04-joins/cc_dbt/models/intermediates/enriched_orders 

# Write model and schema YAML (force rewrite)
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt dml.rolling_features.sql models/intermediates/rolling_features --write --force

# Provide a DDL for schema extraction
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt ../04-joins/cc-flink/dml.enriched_orders.sql ../04-joins/cc_dbt/models/intermediates/enriched_orders --ddl-file ../04-joins/cc-flink/ddl.enriched_orders.sql    --write --force

# Override a ref name for dbt source resolution
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt dml.rolling_features.sql models/intermediates/rolling_features --write --ref-overrides events:src_events

# Override DDL discovery or ref() mapping
uv run python  -m flink_dbt_migrate.migrate_dml_to_dbt \
  ../10-windowing/tumble_then_hop_rolling/dml.rolling_features.sql \
  ../../dbt/airbnb_streaming/models/intermediates/ \
  --ddl-file ../10-windowing/tumble_then_hop_rolling/ddl.rolling_features.sql \
  --ref-table events=src_events \
  --write

# Validate migration with dbt compile (compare query body + reconstructed INSERT)
uv sync --extra validate
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt \
    ../04-joins/cc-flink/dml.enriched_orders.sql \
    ../04-joins/cc_dbt/models/intermediates/enriched_orders \
    --ddl-file ../04-joins/cc-flink/ddl.enriched_orders.sql \
    --write --force  --validate ß
```

```

#### Output Files

- `<target>.sql`:  dbt model SQL with templated refs and migrated Flink options.
- `<target>.schema.yml` or `schema.yml`:  YAML file defining column types and descriptions for dbt.

See the test cases in [`tests/test_migrate_dml_to_dbt.py`](../tests/test_migrate_dml_to_dbt.py) for programmatic usage and advanced patterns.

* 

## Validation (`--validate`)

`--validate` writes the generated model temporarily (restored unless `--write`), runs `dbt compile --select {model}`, and compares:

1. **Query body** — source DML `SELECT`/`WITH` body vs compiled model SQL (refs normalized back to source table names)
2. **Reconstructed INSERT** — `INSERT INTO {target} {compiled_body}` shown for inspection alongside the source DML

Install dbt for validation:

```sh
cd code/flink-sql/tools
uv sync --extra validate
```

Prerequisites:

- `target_dir` must live under a dbt project (`dbt_project.yml` is auto-discovered walking up from `target_dir`, or pass `--dbt-project-dir`)
- Upstream `{{ ref() }}` targets must already exist as dbt models or sources in that project
- `~/.dbt/profiles.yml` must define the project profile (e.g. `cc_flink`); run `dbt debug` in the target project first

On success:

```
Validation passed: query body matches source DML
Reconstructed INSERT INTO rolling_features (N lines)
```

On mismatch, a unified diff of the normalized query bodies is printed plus the reconstructed INSERT for inspection.

DDL auto-discovery (override with `--ddl-file`):

1. `dml.{stem}.sql` → sibling `ddl.{stem}.sql`
2. Else `ddl.{target_table}.sql` in the same folder

Outputs:

- `{model_name}.sql` — `{{ config(materialized='streaming_table', with={...}) }}` plus SELECT body (no `INSERT INTO`)
- `schema.yml` — merged model entry with `columns[].data_type` from DDL

Upstream tables in `FROM` / `JOIN` are resolved automatically (CTE names are skipped):

- If the table already exists as a dbt model in the target project, or `--ref-table TABLE=MODEL` maps it, the migration uses `{{ ref() }}`.
- Otherwise the tool searches the source Flink project for a parent DDL (`ddl.{table}.sql`, `ddl.{suffix}.sql`, or any `ddl*.sql` defining the table) and:
  - rewrites the reference to `{{ source('...', 'table') }}`
  - merges a `sources.yaml` entry at `{dbt_project}/models/sources.yaml` with column types from the parent DDL

Example (`04-joins`):

```sh
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt \
  ../04-joins/cc-flink/dml.enriched_orders.sql \
  ../04-joins/cc_dbt/models/intermediates/enriched_orders \
  --ddl-file ../04-joins/cc-flink/ddl.enriched_orders.sql \
  --write --force
```

Produces `{{ source('cc_flink', 'd04_orders') }}` in the model and updates `cc_dbt/models/sources.yaml`.

Flags:

| Flag | Purpose |
|------|---------|
| `--source-project-dir PATH` | Flink SQL folder to search for parent DDLs (default: DML file directory) |
| `--source-name TEXT` | dbt source group name (default: sanitized folder name, e.g. `cc_flink`) |
| `--no-sources` | Skip source discovery; keep `ref()`-only rewrite |

Limitations (v1): `INSERT INTO ... VALUES` and CTAS are not supported; batch migration from `deploy_manifest.json` is one file per invocation. If multiple DDL files define the same table, the non-`_wm` file is preferred.

Entry point: `flink-sql-migrate-dbt` (when the tools package is installed with entry points).