# Migrate Flink DML to dbt

## Problem Statement

The classical use case for Confluent Cloud Flink development is to start writing Flink SQL in the Confluent Workspace, iterating incrementally, and then committing the SQL to a git repository. Adopting dbt requires developers to manually refactor that Flink SQL into dbt template syntax, update YAML files, and validate the translation — all of which is error-prone and time-consuming.

Projects managed by the `shift_left` utilities adopt a specific folder structure and enforce best practices. This tool provides an automated migration path from those `shift_left` projects to dbt.

## Goals

- Transform one or more Flink SQL queries (DDL, DML, or CTAS) into dbt-ready models
- Generate `<model_name>.sql` dbt model files from DML `INSERT INTO ... SELECT` statements
- Generate per-model `schema.yml` definitions from DDL column types
- Wire upstream tables as `{{ ref() }}` (dbt-managed models) or `{{ source() }}` (external Flink tables)

## Requirements

- [x] Exposed as CLI command via Typer: `flink_dbt_migrate.migrate_dml_to_dbt`
- [x] Dry-run mode (prints model SQL + `schema.yml` to stdout without writing files)
- [x] Extract schema definition from a DDL file to generate `schema.yaml`
- [x] Infer schema from DML or an existing sibling DDL file with the same stem
- [x] Derive model name from the `INSERT INTO` target table; overrideable via CLI
- [x] One `schema.yml` per model directory (modular, avoids a single giant file)
- [x] Default materialization `streaming_table`; overrideable via `--materialized`
- [x] Optional change-detection: stop if generated output differs from existing files (`--check`)
- [x] Force overwrite for model and schema (`--force`)
- [x] Resolve upstream tables from `FROM` / `JOIN` / `TABLE(...)` as `{{ ref() }}` or `{{ source() }}`; generates/updates `sources.yaml`
- [x] Transform `INSERT INTO ... VALUES` DML into a dbt CSV seed + `seeds/schema.yml` entry (auto-detected by `migrate` and `migrate-sl-folder`)
- [ ] Validate generated Flink SQL after `dbt compile` against the source DML
- [ ] Full project migration: <https://github.com/jbcodeforce/flink_project_demos/tree/main/customer_360/c360_flink_processing>


---

## Module Map

| File | Responsibility |
|------|---------------|
| [`migrate_dml_to_dbt.py`](migrate_dml_to_dbt.py) | CLI entry point (Typer). Two commands: `migrate` (single DML) and `migrate-sl-folder` (batch crawl). Orchestrates validation flow. |
| [`migrate.py`](migrate.py) | Core orchestrator `migrate_dml_to_dbt()`. Calls all parse/emit/discover modules and returns a `MigrationResult`. |
| [`parse_dml.py`](parse_dml.py) | Parses `INSERT INTO … SELECT` DML (target table + `SELECT` body; rejects CTAS) and `INSERT INTO … VALUES` DML (target table, optional column list, typed literal rows) via `parse_values_dml()` / `is_values_insert()`. |
| [`parse_ddl.py`](parse_ddl.py) | Parses `CREATE TABLE` DDL. Extracts column names + Flink types, primary key, `DISTRIBUTED BY`, and `WITH(…)` connector options. |
| [`type_map.py`](type_map.py) | Maps Flink column types (`STRING`, `BIGINT`, `TIMESTAMP(3)`, `DECIMAL(10,2)`, …) to dbt `data_type` strings. |
| [`discover_deps.py`](discover_deps.py) | Scans the DML body for upstream tables (`FROM`, `JOIN`, `TABLE`). Resolves each to a `ref` (already a dbt model) or `source` (needs a Flink DDL lookup). |
| [`rewrite_refs.py`](rewrite_refs.py) | Rewrites bare Flink table names in the SQL body to `{{ ref('model') }}` or `{{ source('name', 'table') }}` Jinja calls. Skips CTE names. |
| [`emit_model.py`](emit_model.py) | Builds the final dbt model `.sql` file: `{{ config(…) }}` block + migration comment + rewritten SQL body. |
| [`emit_schema.py`](emit_schema.py) | Builds (or merges into) the per-directory `schema.yml` with column `data_type` entries from the DDL. |
| [`emit_seed.py`](emit_seed.py) | Builds the dbt seed `.csv` from parsed `VALUES` rows, and builds (or merges into) `seeds/schema.yml` with `config.column_types` from the DDL. |
| [`emit_sources.py`](emit_sources.py) | Builds (or merges into) the project-level `sources.yaml` with entries for each upstream table that is a Flink source (not a dbt model). |
| [`validate_compile.py`](validate_compile.py) | Runs `dbt compile --select {model}`, reads the compiled SQL from `target/compiled/`, and resolves relation aliases from `manifest.json`. |
| [`compare_sql.py`](compare_sql.py) | Normalises and diffs the source DML body against the compiled model SQL. Produces a pass/fail report with a unified diff on mismatch. |
| [`temp_write.py`](temp_write.py) | Writes model/schema files temporarily for `dbt compile` (used by `--validate` without `--write`), then restores the originals. |

---

## Sequence Flow — `migrate-sl-folder`

This is the batch command that migrates a full `shift_left` pipelines folder.

```
CLI: migrate-sl-folder <pipeline_dir> <dbt_project_dir> [--write] [--force]
      │
      ▼
migrate_dml_to_dbt.py :: crawl_pipeline_folder(pipeline_dir)
  │
  ├── walks pipeline_dir recursively for sql-scripts/ directories
  ├── for each table/ directory:
  │     ├── reads pipeline_definition.json → upstream_ddl_map {table → ddl_path}
  │     └── for each dml.*.sql found:
  │           ├── parse_dml.py :: is_values_insert()    → detects INSERT INTO ... VALUES seeds
  │           ├── parse_dml.py :: parse_dml() / parse_values_dml() → target_table
  │           ├── parse_dml.py :: discover_ddl_path()  → sibling ddl.*.sql path
  │           └── builds TableEntry {table_name, dml_path, ddl_path, sha256, relative_path, upstream_ddl_map, is_seed}
  │
  ▼
prints discovered inventory (table names + sha256 preview)
  │
  ├── (dry-run: stops here if --write not passed)
  │
  ▼
for each TableEntry:
  ├── is_seed=True  → migrate.py :: migrate_values_dml_to_seed()  [see VALUES→seed flow below]
  │                   writes {seed}.csv + schema.yml under dbt_project/seeds/
  └── is_seed=False → migrate.py :: migrate_dml_to_dbt()          [see single-file flow below]
                      writes {model}.sql + schema.yml under dbt_project/models/<relative_path>/
                      writes sources.yaml under dbt_project/models/ (if upstream sources exist)
```

---

## Sequence Flow — `migrate` (single DML file)

This is the single-file command and the inner loop used by `migrate-sl-folder`. When running from the cli, it is important to set the dbt project upfront, with command like: `uv run tools/sl_dbt.py init crm-analytics --type kimball --profile cc_flink`

```
CLI: migrate <dml_file> <target_dir> [options]
      │
      ▼
migrate_dml_to_dbt.py :: migrate()
  │
  ▼
migrate.py :: migrate_dml_to_dbt(statement_file, target_dir, ...)
  │
  ├─[1] parse_dml.py :: parse_dml(dml_text)
  │       Regex-extracts INSERT INTO target_table and the SELECT body.
  │       Returns DmlStatement {target_table, body, leading_comments}.
  │
  ├─[2] parse_dml.py :: discover_ddl_path(dml_path, target_table, ddl_file?)
  │       Looks for sibling DDL in order:
  │         a) --ddl-file override
  │         b) ddl.<same-stem>.sql in the same folder
  │         c) ddl.<target_table>.sql in the same folder
  │         Raises FileNotFoundError if nothing is found.
  │
  ├─[3] parse_ddl.py :: parse_ddl(ddl_text)
  │       Parses CREATE TABLE: extracts columns (name + Flink type + NOT NULL),
  │       PRIMARY KEY, DISTRIBUTED BY, and WITH(…) connector options.
  │       Returns DdlTable.
  │
  ├─[4] discover_deps.py :: resolve_upstream_deps(source_project_dir, dbt_project_dir, dml, ...)
  │       a) rewrite_refs.py :: collect_cte_names(body)  — skip CTE aliases
  │       b) collect_upstream_tables(body, cte_names)    — regex scan FROM/JOIN/TABLE(…)
  │       c) for each upstream table:
  │            - if in --ref-table overrides   → resolution=ref  (explicit mapping)
  │            - if found as a .sql model in dbt_project/models/  → resolution=ref
  │            - if --no-sources               → resolution=ref  (keep as ref, no DDL lookup)
  │            - else: discover_upstream_ddl() searches source_project_dir for ddl.*.sql
  │                    that CREATE TABLEs the given name → resolution=source
  │       Returns list[UpstreamDep {table_name, ddl_path, ddl, resolution, ref_model/source_name}].
  │
  ├─[5] emit_model.py :: emit_model_sql(dml, ddl, materialized, upstream_deps, ...)
  │       a) emit_model.py :: format_config_block(ddl, materialized)
  │            Builds {{ config(materialized='streaming_table', with={...}) }}
  │            including WITH options and DISTRIBUTED BY from the DDL.
  │       b) rewrite_refs.py :: rewrite_refs(body, cte_names, ref_overrides, ref_tables, source_tables)
  │            Rewrites each upstream table in FROM/JOIN/TABLE(…) to:
  │              {{ ref('model_name') }}       for ref-resolved tables
  │              {{ source('src', 'table') }}  for source-resolved tables
  │       Returns the complete dbt model SQL string.
  │
  ├─[6] emit_schema.py :: emit_schema_yml(target_dir, model_name, ddl, ...)
  │       a) loads existing schema.yml from target_dir (or starts fresh)
  │       b) type_map.py :: flink_type_to_dbt(flink_type)  — maps each column type
  │       c) merges the new model entry into the YAML (adds columns, preserves extras)
  │          --force replaces the existing entry entirely
  │       Returns the YAML string.
  │
  ├─[7] emit_sources.py :: emit_sources_yml(models_dir, source_name, upstream_deps, ...)
  │       Only runs when upstream_deps contain source-resolved tables AND a dbt project was found.
  │       a) loads existing sources.yaml from dbt_project/models/ (or starts fresh)
  │       b) for each source dep: type_map.py :: flink_type_to_dbt() per column
  │       c) merges table entries under the source group name (default: sanitized folder name)
  │       Returns the YAML string (or None if no source deps).
  │
  └─[8] Returns MigrationResult {model_sql, schema_yml, sources_yml, model_path, schema_path, ...}
          │
          ▼
      CLI writes files (--write) or prints to stdout (dry-run)
```

---

## Sequence Flow — `INSERT INTO ... VALUES` → dbt seed

`migrate` auto-detects this shape (via `is_values_insert()`) and routes here instead of the model
flow above; `target_dir` is then treated as the dbt project's `seeds/` directory.

```
migrate_dml_to_dbt.py :: migrate()  — is_values_insert(dml_text) is True
  │
  ▼
migrate_dml_to_dbt.py :: run_migrate_seed()
  │
  ▼
migrate.py :: migrate_values_dml_to_seed(statement_file, seeds_dir, ...)
  │
  ├─[1] parse_dml.py :: parse_values_dml(dml_text)
  │       Extracts target_table, an optional column list, and typed literal rows
  │       (DATE '...', TIMESTAMP '...', quoted strings with '' escapes, NULL, numbers).
  │       Returns ValuesDmlStatement {target_table, columns, rows}.
  │
  ├─[2] parse_dml.py :: discover_ddl_path() + parse_ddl.py :: parse_ddl()
  │       Same sibling-DDL discovery as the model flow. If the VALUES statement
  │       omitted a column list, the DDL's column order is used instead
  │       (row arity must then match the DDL's column count).
  │
  ├─[3] emit_seed.py :: emit_seed_csv(columns, rows)
  │       Writes standard CSV (csv.writer, QUOTE_MINIMAL) — header + one row per tuple.
  │
  ├─[4] emit_seed.py :: emit_seed_schema_yml(seeds_dir, seed_name, ddl, ...)
  │       a) loads existing seeds/schema.yml (or starts fresh)
  │       b) builds a `seeds:` entry with `config.column_types` (type_map.py per column)
  │          and, if the DDL declares WITH(...) options, a `meta.flink_ddl_with_options`
  │          block (informational only — dbt-confluent's seed materialization does not
  │          apply Kafka connector options; it issues a plain CREATE TABLE + batched INSERT)
  │       c) merges into the YAML, preserving extras unless --force
  │
  └─[5] Returns SeedMigrationResult {csv_text, schema_yml, csv_path, schema_path, ddl_path}
          │
          ▼
      CLI writes files (--write) or prints to stdout (dry-run)
```

---

## Sequence Flow — `--validate`

Runs after the model is generated, optionally writing it temporarily.

```
--validate flag
  │
  ├── temp_write.py :: begin_temp_write()
  │     Writes model.sql + schema.yml to target_dir temporarily.
  │     Saves originals so they can be restored if --write was not passed.
  │
  ├── validate_compile.py :: find_dbt_project(target_dir)
  │     Walks up the directory tree looking for dbt_project.yml.
  │
  ├── validate_compile.py :: validate_compiled_migration(project_dir, model_path, model_name, ...)
  │     a) run_dbt_compile(): runs `dbt compile --select {model_name}`
  │     b) resolves compiled output path from dbt_project.yml project name
  │     c) reads compiled SQL from target/compiled/<project>/<model>.sql
  │     Returns DbtCompileResult {compiled_sql, ...}.
  │
  ├── validate_compile.py :: resolve_ref_aliases(project_dir, model_name, ref_overrides)
  │     Reads target/manifest.json to map dbt relation names (e.g. `env`.`schema`.`table`)
  │     back to the original Flink table names, for accurate SQL comparison.
  │
  ├── compare_sql.py :: compare_migration(source_dml, compiled_sql, ref_aliases)
  │     a) apply_ref_aliases(): substitutes relation names with bare source table names
  │     b) normalize_sql(): strips comments, collapses whitespace, lowercases
  │     c) diffs normalized source body vs normalized compiled body
  │     Returns CompareResult {body_match, body_diff, reconstructed_insert, ...}.
  │
  ├── temp_write.py :: restore_temp_write()   (only if --write was not passed)
  │     Restores any files that existed before the temp write.
  │
  └── prints compare report; exits 1 on mismatch
```

---

## Usage

### Prerequisites

1. Create a dbt project (example using [`sl_dbt.py`](../sl_dbt.py)):
   ```sh
   cd flink-studies/code/dbt
   uv run tools/sl_dbt.py init /path/to/c360_flink_dsp_dbt/ --profile cc_flink
   ```
   This scaffolds:
   ```
   c360_flink_dsp_dbt/
   ├── pipelines/
   │   ├── dbt_project.yml
   │   ├── macros/
   │   ├── models/
   │   ├── seeds/
   │   └── tests/
   └── sl_dbt.yaml
   ```

2. Add your Confluent Cloud profile to `~/.dbt/profiles.yml`:
   ```yaml
   cc_flink:
     outputs:
       dev:
         type: confluent
         cloud_provider:
         cloud_region:
         compute_pool_id: lfcp-
         dbname: j9r-kafka
         environment_id: env-
         execution_mode: streaming_query
         flink_api_key: '{{ env_var(''CONFLUENT_FLINK_API_KEY'') }}'
         flink_api_secret: '{{ env_var(''CONFLUENT_FLINK_API_SECRET'') }}'
         organization_id: 4...
         statement_name_prefix: dbt-
         threads: 1
     target: dev
   ```

3. Export your API credentials:
   ```sh
   export CONFLUENT_FLINK_API_KEY=...
   export CONFLUENT_FLINK_API_SECRET=...
   ```

---

### Commands

All commands are run from `flink-studies/code/dbt/`:

#### Batch-migrate an entire `shift_left` pipelines folder

```sh
# Dry-run: discover tables and print inventory, no files written
uv run flink_dbt_migrate/migrate_dml_to_dbt.py migrate-sl-folder \
  ~/Documents/Code/flink_project_demos/customer_360/c360_flink_processing/pipelines \
  ~/Documents/Code/flink_project_demos/customer_360/c360_flink_dsp_dbt/pipelines

# Write all model files to the dbt project
uv run flink_dbt_migrate/migrate_dml_to_dbt.py migrate-sl-folder \
  ~/Documents/Code/flink_project_demos/customer_360/c360_flink_processing/pipelines \
  ~/Documents/Code/flink_project_demos/customer_360/c360_flink_dsp_dbt/pipelines \
  --write
```

Once the migration done, use dbt cli to validate the deployment

```sh
cd ~/Documents/Code/flink_project_demos/customer_360/c360_flink_dsp_dbt/pipelines
dbt debug
dbr run
```

#### Migrate a single DML file

```sh
# Dry-run (prints model SQL + schema.yml to stdout)
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  dml.rolling_features.sql \
  models/intermediates/rolling_features

# Write model and schema YAML (force rewrite of existing files)
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  dml.rolling_features.sql \
  models/intermediates/rolling_features \
  --write --force
```

#### Provide an explicit DDL for schema extraction

```sh
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  ../04-joins/cc-flink/dml.enriched_orders.sql \
  ../04-joins/cc_dbt/models/intermediates/enriched_orders \
  --ddl-file ../04-joins/cc-flink/ddl.enriched_orders.sql \
  --write --force
```

#### Migrate an `INSERT INTO ... VALUES` seed file

`migrate` auto-detects `VALUES` DML and writes a CSV seed + `seeds/schema.yml` entry instead of a model:

```sh
# Dry-run (prints CSV + schema.yml to stdout)
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  seeds/app_usage_raw/sql-scripts/dml.app_usage_raw.sql \
  seeds

# Write the seed CSV and merge the schema.yml entry
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  seeds/app_usage_raw/sql-scripts/dml.app_usage_raw.sql \
  seeds --write --force
```

`migrate-sl-folder` does the same automatically for any `dml.*.sql` file it identifies as a `VALUES`
statement, writing under `dbt_project_dir/seeds/` instead of `models/`.

#### Override a ref name for dbt source resolution

```sh
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  dml.rolling_features.sql \
  models/intermediates/rolling_features \
  --write \
  --ref-table events=src_events
```

#### Override DDL discovery and ref() mapping

```sh
uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  ../10-windowing/tumble_then_hop_rolling/dml.rolling_features.sql \
  ../../dbt/airbnb_streaming/models/intermediates/ \
  --ddl-file ../10-windowing/tumble_then_hop_rolling/ddl.rolling_features.sql \
  --ref-table events=src_events \
  --write
```

#### Validate migration with `dbt compile`

```sh
uv sync --extra validate   # install dbt if not already present

uv run python -m flink_dbt_migrate.migrate_dml_to_dbt migrate \
  ../../flink-sql/04-joins/cc-flink/dml.enriched_orders.sql \
  ../../flink-sql/04-joins/cc_dbt/models/intermediates/enriched_orders \
  --ddl-file ../../flink-sql/04-joins/cc-flink/ddl.enriched_orders.sql \
  --write --force --validate
```

Prerequisites for `--validate`:
- `target_dir` must live under a dbt project (`dbt_project.yml` is auto-discovered walking up)
- Upstream `{{ ref() }}` targets must already exist as models or sources in that project
- `~/.dbt/profiles.yml` must define the project profile; run `dbt debug` in the project first

---

### CLI Reference

#### `migrate-sl-folder` options

| Argument / Option | Description |
|---|---|
| `PIPELINE_DIR` | Path to a `shift_left` `pipelines/` folder (or sub-folder) |
| `DBT_PROJECT_DIR` | dbt project root; models are written under `models/` mirroring the pipeline hierarchy |
| `--write` | Write output files. Without this flag, only the inventory is printed (dry-run). |
| `--force` | Overwrite existing model and schema entries |
| `--materialized TEXT` | dbt materialization (default: `streaming_table`) |

#### `migrate` options

| Option | Description |
|---|---|
| `--ddl-file PATH` | Override auto-discovered DDL file |
| `--model-name TEXT` | Override model name (default: `INSERT INTO` target table) |
| `--materialized TEXT` | dbt materialization (default: `streaming_table`) |
| `--ref-table TABLE=MODEL` | Map an upstream table to a specific `{{ ref() }}` model (repeatable) |
| `--write` | Write `.sql` and `schema.yml` to `target_dir` |
| `--force` | Overwrite existing files |
| `--check` | Exit 1 if output would differ from existing files (CI mode) |
| `--validate` | Run `dbt compile` and compare compiled SQL to source DML |
| `--dbt-project-dir PATH` | dbt project root (default: auto-discovered from `target_dir`) |
| `--dbt-target TEXT` | dbt target name (default: `dev`) |
| `--dbt-profiles-dir PATH` | dbt profiles directory (default: `~/.dbt`) |
| `--source-project-dir PATH` | Flink SQL folder to search for upstream DDLs (default: DML file directory) |
| `--source-name TEXT` | dbt source group name (default: sanitized source folder name) |
| `--no-sources` | Skip upstream source discovery; keep `ref()`-only rewrite |
| `--seed-name TEXT` | For `INSERT INTO ... VALUES` files only: override the seed name (default: `--model-name`, then the `INSERT INTO` target table) |

---

### Output Files

| File | Contents |
|---|---|
| `<model_name>.sql` | dbt model with `{{ config(materialized='streaming_table', with={...}) }}` block, migration comment, and SELECT body with `{{ ref() }}` / `{{ source() }}` rewrites |
| `schema.yml` | Per-directory YAML with `version: 2`, model `columns[].data_type` from DDL, merged with any existing entries |
| `models/sources.yaml` | Project-level YAML with source table entries (only created/updated when upstream source tables are found) |
| `seeds/<seed_name>.csv` | Standard CSV (header + one row per `VALUES` tuple) for `INSERT INTO ... VALUES` DML |
| `seeds/schema.yml` | Per-`seeds/`-directory YAML with `version: 2`, `seeds[].config.column_types` from DDL, merged with any existing entries |

---

### DDL Auto-discovery Order

When no `--ddl-file` is given, the tool looks in the DML file's directory in this order:

1. `ddl.<same-stem-as-dml>.sql` — e.g. for `dml.enriched_orders.sql` → `ddl.enriched_orders.sql`
2. `ddl.<target_table>.sql` — using the table name from `INSERT INTO`

For upstream dependencies, the search also scans all `ddl*.sql` files in `source_project_dir` for a `CREATE TABLE` matching the table name. If multiple files match, the non-`_wm` (non-watermark) file is preferred.

---

### Upstream Dependency Resolution

For each table referenced in `FROM`, `JOIN`, or `TABLE(…)`:

| Condition | Result |
|---|---|
| Table name is a CTE alias | Skipped — not rewritten |
| `--ref-table TABLE=MODEL` was passed | `{{ ref('MODEL') }}` |
| Table exists as `*.sql` under `dbt_project/models/` | `{{ ref('table') }}` |
| `--no-sources` flag set | `{{ ref('table') }}` (no DDL lookup) |
| DDL found in source project for the table | `{{ source('source_name', 'table') }}` + entry added to `sources.yaml` |

---

## Limitations (v1)

- CTAS (`CREATE TABLE … AS SELECT`) is not supported
- `INSERT INTO … VALUES` seeds: only literal values are supported (no expressions/functions in
  cell position); the DDL's `WITH(...)` connector options are recorded as informational
  `meta.flink_ddl_with_options` but are **not** applied by dbt-confluent's `seed` materialization,
  which issues a plain `CREATE TABLE` + a single batched `INSERT` (no chunking — see
  `get_batch_size()` in the adapter)
- Multiple DDL files defining the same table: the non-`_wm` file is preferred
- Batch migration reads one DML file per `sql-scripts/` directory

---

## See Also

- Test cases: [`tests/test_migrate_dml_to_dbt.py`](../tests/test_migrate_dml_to_dbt.py), [`tests/test_seed_migration.py`](../tests/test_seed_migration.py)
- Entry point when tools package is installed: `flink-sql-migrate-dbt`
