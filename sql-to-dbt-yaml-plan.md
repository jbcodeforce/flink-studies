# Plan: sql_to_dbt_yaml — Parse dbt SQL and Generate Model YAML

## Overview

Add a new CLI tool `code/dbt/tools/sql_to_dbt_yaml.py` that:

1. Accepts a path to any dbt SQL model file (`.sql`) as input.
2. Parses the SQL to discover which upstream models are referenced via `{{ ref('...') }}`.
3. Loads the YAML column definitions for each upstream model (recursively, supporting `SELECT *`).
4. Walks the final SELECT list and resolves each output column's name and data type by:
   - Direct pass-through (`l.listing_id` → type from upstream)
   - Column alias (`h.is_superhost AS host_is_superhost` → same type, new name)
   - `CAST(... AS type)` expressions → extract the target type literally
   - Functions like `GREATEST(a, b)` → inherit type from the first resolvable argument
   - Derived expressions with no resolvable type → fall back to `string`
5. Prints a `models:` YAML block to stdout (same format as `render_model_yaml()` in `schema_registry.py`).

**Scope**: New standalone script + optional addition to `pyproject.toml` deps (only `sqlglot` and `pyyaml`). No changes to the shared library. Output is stdout only.

---

## Sub-Tasks

---

### Sub-Task 1 — Add `sqlglot` dependency

**Intent**: `sqlglot` is a pure-Python SQL parser that handles Jinja-stripped SQL reliably. It needs to be declared as a project dependency so `uv run` picks it up automatically.

**Expected Outcomes**:
- `sqlglot` appears in `code/dbt/tools/pyproject.toml` dependencies.
- `uv.lock` is regenerated (or noted as needing regeneration).

**Todo List**:
1. Add `sqlglot>=25.0.0` to the `dependencies` list in `code/dbt/tools/pyproject.toml`.
2. Run `uv lock` inside `code/dbt/tools/` to update the lock file.

**Relevant Context**:
- [`code/dbt/tools/pyproject.toml`](code/dbt/tools/pyproject.toml)

**Status**: [ ] pending

---

### Sub-Task 2 — Implement SQL parser module: `sql_parser.py`

**Intent**: Isolate the SQL parsing logic into a reusable module. This keeps the CLI thin and makes the parser independently testable.

**Expected Outcomes**:
- `code/dbt/tools/sql_parser.py` exists and exposes:
  - `strip_jinja_config(sql: str) -> str` — removes `{{ config(...) }}` blocks, leaving valid SQL.
  - `extract_refs(sql: str) -> list[str]` — returns all model names from `{{ ref('name') }}`.
  - `parse_select(sql: str) -> list[SelectItem]` — parses the final SELECT's column list into structured items with `name`, `alias`, `table_alias`, `expression`.
  - `dataclass SelectItem` with fields for the above.

**Todo List**:
1. Use regex to strip the Jinja `{{ config(...) }}` block (multi-line, balanced braces).
2. Replace all remaining `{{ ref('model') }}` tokens with a bare identifier `model` before passing to sqlglot.
3. Use `sqlglot.parse_one()` to get the AST of the cleaned SQL.
4. Walk the final (outermost) SELECT expression list, extracting alias, table qualifier, and the raw expression node for each column.
5. For `SelectItem` with no alias, derive the output name from the column name or expression.

**Relevant Context**:
- [`dim_listings_with_hosts.sql`](code/dbt/airbnb_streaming/models/user_reviews/dimensions/dim_listings_with_hosts.sql) — representative SQL with CTEs, JOIN, aliases, and expressions.
- [`src_hosts.sql`](code/dbt/airbnb_streaming/models/user_reviews/sources/src_hosts.sql) — SQL with ROW_NUMBER window function and WHERE filter.

**Status**: [ ] pending

---

### Sub-Task 3 — Implement model YAML resolver: `model_resolver.py`

**Intent**: Given a model name and a dbt project root, find and load the model's YAML file to extract its column definitions. Supports recursive `SELECT *` expansion.

**Expected Outcomes**:
- `code/dbt/tools/model_resolver.py` exists and exposes:
  - `ModelResolver(project_root: Path)` class.
  - `get_columns(model_name: str) -> list[ColumnSpec]` — returns the column list for a model, walking its SQL if necessary (for `SELECT *` models).
  - `find_model_yaml(model_name: str) -> Path | None` — locates the `.yml` file for the model by scanning the project's `models/` directory.
  - `find_model_sql(model_name: str) -> Path | None` — locates the `.sql` file similarly.

**Todo List**:
1. Scan the project's `models/` directory recursively for `*_models.yml` and `*.yml` files.
2. Parse each YAML file; match on `models[].name == model_name` to extract its `columns` list.
3. Return columns as `ColumnSpec(name, data_type)` (reuse the dataclass from `schema_registry.py` via the shared lib path, or define a local equivalent).
4. If the model YAML has no columns (e.g., intermediate models), find the model's `.sql` file and recursively invoke the SQL parser + resolver on it — this handles the `SELECT *` chain.
5. Locate `dbt_project.yml` to determine the project root's `model-paths` config (default: `models/`).

**Relevant Context**:
- [`schema_registry.py` — `ColumnSpec` dataclass](code/flink-sql/cm_py_lib/schema_registry.py:153)
- [`src_hosts_models.yml`](code/dbt/airbnb_streaming/models/user_reviews/sources/src_hosts_models.yml) — target YAML format to read.
- [`dim_hosts_cleansed.sql`](code/dbt/airbnb_streaming/models/user_reviews/dimensions/dim_hosts_cleansed.sql) — example of a model with `SELECT *` from a ref (needs recursive resolution).
- [`dbt_project.yml`](code/dbt/airbnb_streaming/dbt_project.yml)

**Status**: [ ] pending

---

### Sub-Task 4 — Implement type inference: `type_inferrer.py`

**Intent**: Given a `SelectItem` and the column catalog built from upstream models, resolve the output data type. Handles pass-throughs, aliases, CAST, and common SQL functions.

**Expected Outcomes**:
- `code/dbt/tools/type_inferrer.py` exists and exposes:
  - `infer_type(item: SelectItem, catalog: dict[str, dict[str, str]]) -> str`
    where `catalog` maps `table_alias -> {col_name -> data_type}`.
  - Returns the resolved type string or `"string"` as fallback.

**Todo List**:
1. For a plain column reference (`l.listing_id`): look up `catalog["l"]["listing_id"]`.
2. For `CAST(expr AS type)`: extract the cast target type string directly from the AST.
3. For `GREATEST(a, b)` and similar single-type-propagating functions: resolve the type of the first resolvable argument.
4. For `COALESCE(col, literal)`: use the type of the first non-literal argument.
5. For unresolvable expressions: return `"string"` as fallback.
6. Map sqlglot AST type nodes to dbt/Flink type strings (e.g., `DECIMAL(10,2)` → `"decimal(10,2)"`).

**Relevant Context**:
- [`dim_listings_with_hosts.sql`](code/dbt/airbnb_streaming/models/user_reviews/dimensions/dim_listings_with_hosts.sql:40) — `GREATEST(l.updated_at, h.updated_at)` is the key expression to resolve.
- [`dim_listings_cleansed.sql`](code/dbt/airbnb_streaming/models/user_reviews/dimensions/dim_listings_cleansed.sql:34) — `CAST(REPLACE(price_str, '$', '') AS DECIMAL(10,2))` as a CAST example.
- [`dim_hosts_cleansed.sql`](code/dbt/airbnb_streaming/models/user_reviews/dimensions/dim_hosts_cleansed.sql:26) — `COALESCE(host_name, 'Anonymous')` example.

**Status**: [ ] pending

---

### Sub-Task 5 — Implement the CLI: `sql_to_dbt_yaml.py`

**Intent**: Wire the parser, resolver, and type inferrer together in a CLI that mirrors the style of `sr_to_dbt_yaml.py`.

**Expected Outcomes**:
- `code/dbt/tools/sql_to_dbt_yaml.py` exists and is runnable via `uv run sql_to_dbt_yaml.py`.
- Running against `dim_listings_with_hosts.sql` produces a correct `models:` YAML block with all 10 columns and their inferred types.
- `--help` describes all flags.

**Todo List**:
1. Define CLI args:
   - `sql_file` (positional) — path to the `.sql` file.
   - `--project-root` (optional) — path to dbt project root; defaults to auto-detection by walking up from the SQL file to find `dbt_project.yml`.
   - `--model-name` (optional) — override the model name in output; defaults to the SQL filename stem.
2. Strip Jinja, parse SQL, build CTE-to-model mapping.
3. For each CTE alias, call `ModelResolver.get_columns()` for the referenced model, building `catalog[alias] = {col: type}`.
4. Walk the final SELECT items, call `infer_type()` for each, collect `ColumnSpec` list.
5. Call `render_model_yaml(model_name, columns)` (reuse from `schema_registry.py` via the same `_cm_py_lib_root` path-setup pattern) and print to stdout.
6. Mirror `sr_to_dbt_yaml.py`'s error-handling style: print errors to stderr and return non-zero exit code.

**Relevant Context**:
- [`sr_to_dbt_yaml.py`](code/dbt/tools/sr_to_dbt_yaml.py) — pattern to follow for CLI structure and `_cm_py_lib_root()` reuse.
- [`schema_registry.py` — `render_model_yaml()`](code/flink-sql/cm_py_lib/schema_registry.py:282)

**Status**: [ ] pending

---

### Sub-Task 6 — Update README

**Intent**: Document the new tool so users know how to run it and what to expect.

**Expected Outcomes**:
- `code/dbt/tools/README.md` has a new `## SQL → dbt Model YAML` section.
- Example shows running against `dim_listings_with_hosts.sql` and the expected YAML output.

**Todo List**:
1. Add section with usage, flags, and a sample output block showing all 10 columns of `dim_listings_with_hosts`.
2. Note that `--project-root` defaults to auto-detection.

**Relevant Context**:
- [`code/dbt/tools/README.md`](code/dbt/tools/README.md)

**Status**: [ ] pending
