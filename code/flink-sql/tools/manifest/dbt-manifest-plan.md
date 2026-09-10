# Plan: dbt Project Support in manifest.py and manifest_cli.py

## Top-Level Overview

Add a **dbt mode** to the existing `manifest.py` / `manifest_cli.py` toolchain so that
`cc_deploy` / `drop-tables` can operate on Flink statements that were deployed by
`dbt-confluent` instead of raw SQL files.

The new mode is triggered by `--dbt` in the CLI (or detected automatically when
`sl_dbt.yaml` is present). It reads **dbt's own `target/manifest.json`** artifact to
discover model names, then reconstructs the exact Flink statement names using the same
`sanitize_statement_name` algorithm that `dbt-confluent` uses. The resulting
`DeployManifest` is structurally identical to the one generated from raw SQL folders, so
all existing deploy/undeploy/drop-tables flows work unchanged.

**Scope**
- `code/flink-sql/tools/manifest/manifest.py` — new `create_manifest_from_dbt_folder()`
- `code/flink-sql/tools/manifest/manifest_cli.py` — new `--dbt` flag
- No changes to `cc_deploy/` or any caller

**Confirmed Design Decisions**
1. **Group naming**: detect group from the deepest path segment matching
   `sources|dimensions|facts|marts`; e.g. `user_reviews/sources/src_hosts.sql` → group
   `sources`. Unrecognised segments fall back to `pipeline`.
2. **`_noop` files + deploy_all**: `file` is set to `"_noop"` (dbt owns deployment).
   `deploy_all` is still populated so callers can query existing statement state.
   `undeploy_all` is populated for teardown.
3. **`drop_tables` scope**: includes dbt model tables, seed tables, **and** raw source
   tables declared in `models/sources.yaml` (e.g. `raw_hosts`, `raw_listings`,
   `raw_reviews`). Raw sources are extracted from `models/**/sources.yaml` files in the
   dbt project. Dependents (facts/dimensions) are listed before sources in the drop
   order.

**Non-goals**
- Do not support running `dbt compile` or any dbt CLI commands
- Do not read `profiles.yml` at deploy time; only read it at manifest-generation time
  to learn the `statement_name_prefix`
- Do not modify the `DeployManifest` model or its serialisation format

---

## Sub-Tasks

---

### Sub-Task 1 — Wire `sanitize_statement_name` from `dbt-confluent` into `manifest.py`

**Intent**
Import `sanitize_statement_name` **directly** from
`dbt.adapters.confluent.naming` rather than recopying it. This avoids drift if
dbt-confluent changes the algorithm in a future release.

`dbt-confluent` is already present in `code/flink-sql/tools/uv.lock` (under the
`validate` optional extra). It needs to be made available for the `--dbt` path by
adding a new `dbt` optional extra (or merging into `validate`) in `pyproject.toml`.

The import is guarded so that the rest of `manifest.py` (non-dbt path) does not require
dbt-confluent installed.

The `get_statement_name` call from `impl.py` is trivially inline:
```python
# prefix from profiles.yml, project_name from dbt_project.yml, model_name from node
raw = f"{prefix}{project_name}-{model_name}"
# or, when explicit statement_name is set in model config:
raw = statement_name_override
sanitize_statement_name(raw)
```

**Expected Outcomes**
- `sanitize_statement_name("dbt-airbnb_streaming-src_hosts")` →
  `"dbt-airbnb-streaming-src-hosts-XXXXXX"` (6-char MD5 hash, underscores replaced)
- `sanitize_statement_name("fw_crm_customers_pk")` →
  `"fw-crm-customers-pk-XXXXXX"`
- A model with explicit `statement_name: 'fw_crm_customers_pk'` uses that value as the
  `raw` input to `sanitize_statement_name`

**Todo List**
- [ ] Add `dbt` optional extra to `code/flink-sql/tools/pyproject.toml`:
      `dbt = ["dbt-confluent>=0.3.0"]`
- [ ] In `manifest.py`, add a lazy import guard at the top of
      `create_manifest_from_dbt_folder()`:
      ```python
      try:
          from dbt.adapters.confluent.naming import sanitize_statement_name as _dbt_sanitize
      except ImportError as exc:
          raise ImportError(
              "dbt-confluent is required for --dbt mode. "
              "Install with: uv sync --extra dbt"
          ) from exc
      ```
- [ ] Use `_dbt_sanitize(raw_name)` wherever a statement name is built in
      `create_manifest_from_dbt_folder()`

**Relevant Context**
- `code/dbt/.venv/lib/python3.12/site-packages/dbt/adapters/confluent/naming.py` —
  `sanitize_statement_name` (15 lines, confirmed stable across 0.3.x)
- `code/flink-sql/tools/pyproject.toml` — `validate` extra already contains
  `dbt-confluent>=0.3.0`; `uv.lock` already has it resolved

**Status** `[ ] pending`

---

### Sub-Task 2 — Add `_read_dbt_project_name()` and `_find_dbt_project_root()` helpers

**Intent**
Locate the dbt project root from a given path and extract the project name from
`dbt_project.yml`.

Discovery order for the project root:
1. If `path` contains `dbt_project.yml` → that is the root.
2. Walk up directory parents looking for `sl_dbt.yaml` (stops at filesystem root).
3. If neither is found, raise `FileNotFoundError`.

The `sl_dbt.yaml` file lives at the project root (alongside `dbt_project.yml`), as seen
in `code/dbt/airbnb_streaming/sl_dbt.yaml`.

**Expected Outcomes**
- Given `code/dbt/airbnb_streaming/models/` → finds `code/dbt/airbnb_streaming/`
- Given `code/dbt/airbnb_streaming/` → finds same (dbt_project.yml present)
- Given an unrelated folder → raises `FileNotFoundError`

**Todo List**
- [ ] Implement `def _find_dbt_project_root(start: Path) -> Path`
- [ ] Implement `def _read_dbt_project_name(project_root: Path) -> str` (reads
      `dbt_project.yml`, returns `name` field value)
- [ ] Handle YAML parse errors with a descriptive `ValueError`

**Relevant Context**
- `code/dbt/airbnb_streaming/dbt_project.yml` — `name: 'airbnb_streaming'`
- `code/dbt/airbnb_streaming/sl_dbt.yaml` — `profile_name: cc_flink`

**Status** `[ ] pending`

---

### Sub-Task 3 — Add `_read_statement_name_prefix()` helper

**Intent**
Parse `~/.dbt/profiles.yml` to find the `statement_name_prefix` for the profile
declared in `dbt_project.yml`. Fall back to `"dbt-"` if the file is missing, the
profile is not found, or the key is absent.

**Expected Outcomes**
- For profile `cc_flink` with `statement_name_prefix: dbt-` in `profiles.yml` →
  returns `"dbt-"`
- If `~/.dbt/profiles.yml` does not exist → returns `"dbt-"`
- If profile name is not found in file → returns `"dbt-"`

**Todo List**
- [ ] Implement `def _read_statement_name_prefix(profile_name: str) -> str`
- [ ] Use `pathlib.Path.home() / ".dbt" / "profiles.yml"` for the file path
- [ ] Parse YAML; traverse `profile_name → outputs → dev → statement_name_prefix`
      (check all outputs keys since target name may vary)
- [ ] Silently return fallback on any parse/missing error

**Relevant Context**
- `dbt_project.yml` → `profile: 'cc_flink'`
- `flink_dbt_migrate/README.md` shows profiles.yml shape with `statement_name_prefix: dbt-`

**Status** `[ ] pending`

---

### Sub-Task 4 — Add `_read_dbt_manifest_nodes()`, `_dbt_group_for_node()`, and `_read_dbt_source_tables()` helpers

**Intent**
Read dbt's `target/manifest.json` and `models/**/sources.yaml` files to extract all
information needed to build the deploy manifest:
- Model nodes: `unique_id`, `name`, `path` (relative path under `models/`), `resource_type`
- Seed nodes: `name`, resource_type = `seed`
- Explicit `statement_name` from `config` if present
- Raw source table names from `models/**/sources.yaml` (for `drop_tables`)

Group mapping — deepest path segment matching a known layer wins:
| path segment | manifest group |
|--------------|----------------|
| `sources`    | `sources`      |
| `dimensions` | `dimensions`   |
| `facts`      | `facts`        |
| `marts`      | `marts`        |
| anything else| `pipeline`     |
| `seed`       | `seeds`        |

**Expected Outcomes**
- From `airbnb_streaming/target/manifest.json`:
  - `src_hosts` (path `user_reviews/sources/src_hosts.sql`) → group `sources`
  - `dim_hosts_cleansed` (path `user_reviews/dimensions/…`) → group `dimensions`
  - `fct_reviews` (path `user_reviews/facts/…`) → group `facts`
  - `seed_full_moon_dates` (resource_type `seed`) → group `seeds`
- Node with explicit `config.statement_name` → that value used as statement name override
- `_read_dbt_source_tables(project_root)` returns `["raw_hosts", "raw_listings",
  "raw_reviews", "raw_full_moon_dates"]` from `models/sources.yaml`

**Todo List**
- [ ] Implement `def _read_dbt_manifest_nodes(project_root: Path) -> list[dict]`
      Reads `target/manifest.json`, returns normalized list with fields:
      `{name, path, resource_type, statement_name_override}`
- [ ] Implement `def _dbt_group_for_node(path: str, resource_type: str) -> str`
      Maps deepest-matching path segment to manifest group
- [ ] Implement `def _read_dbt_source_tables(project_root: Path) -> list[str]`
      Globs `models/**/sources.yaml` and `models/**/sources.yml`, reads each YAML,
      returns all `sources[].tables[].name` values (deduplicated, stable order)
- [ ] Handle missing `target/manifest.json` with a descriptive `FileNotFoundError`
      (guide user to run `dbt run` or `dbt compile` first)

**Relevant Context**
- `code/dbt/airbnb_streaming/target/manifest.json` — node path:
  `nodes["model.airbnb_streaming.src_reviews"].path = "user_reviews/sources/src_reviews.sql"`
- Seeds appear under `nodes` with `resource_type: "seed"`
- Explicit `statement_name` is in `nodes[id].config.statement_name` (string or null)
- `code/dbt/airbnb_streaming/models/sources.yaml` — raw source tables listed under
  `sources[].tables[].name`

**Status** `[ ] pending`

---

### Sub-Task 5 — Implement `create_manifest_from_dbt_folder()`

**Intent**
The main public function that orchestrates Sub-Tasks 1–4 to produce a `DeployManifest`
from a dbt project folder.

Statement name formula:
- If node has explicit `statement_name`: `_dbt_sanitize_statement_name(statement_name_override)`
- Otherwise: `_dbt_sanitize_statement_name(f"{prefix}{project_name}-{model_name}")`

The `file` field in each `StatementRef` is set to `"_noop"` (same convention as
`flink_workshop/teardown_manifest.json`) because there is no raw SQL file to deploy — dbt
manages deployment.

Deploy/undeploy ordering:
- `deploy_all` ordered: `seeds → sources → dimensions → pipeline → facts → marts`
  (whichever groups are present)
 - `undeploy_all` ordered: reverse → `marts → facts → pipeline → dimensions → sources → seeds`

`drop_tables` list — full teardown order (dependents before sources):
1. Model/seed tables from dbt `target/manifest.json`, in undeploy group order (marts,
   facts, pipeline, dimensions, sources, seeds)
2. Raw source tables from `models/**/sources.yaml`, appended last (leaf inputs)

`drop_statement_prefix`: `_dbt_sanitize_statement_name(f"{prefix}{project_name}-drop")`.

**Expected Outcomes**
For `code/dbt/airbnb_streaming/`:
```json
{
  "user_agent": "cc-sql-tools/0.1",
  "groups": {
    "seeds": [
      {"name": "dbt-airbnb-streaming-seed-full-moon-dates-XXXXXX", "file": "_noop"}
    ],
    "sources": [
      {"name": "dbt-airbnb-streaming-src-hosts-XXXXXX", "file": "_noop"},
      ...
    ],
    "dimensions": [...],
    "facts": [...]
  },
  "deploy_all": ["seeds", "sources", "dimensions", "facts"],
  "undeploy_all": ["facts", "dimensions", "sources", "seeds"],
  "drop_tables": [
    "fct_listing_activity", "fct_host_performance", "fct_review_summary",
    "fct_listing_pricing", "fct_reviews",
    "dim_listings_with_hosts", "dim_listings_cleansed", "dim_hosts_cleansed",
    "src_reviews", "src_listings", "src_hosts",
    "seed_full_moon_dates",
    "raw_hosts", "raw_listings", "raw_reviews", "raw_full_moon_dates"
  ],
  "drop_statement_prefix": "dbt-airbnb-streaming-drop-XXXXXX"
}
```

**Todo List**
- [ ] Implement `create_manifest_from_dbt_folder(project_root, *, write, overwrite,
      manifest_name, user_agent)` in `manifest.py`
- [ ] Accept `project_root: Path` (already resolved by CLI) 
- [ ] Wire together Sub-Tasks 1–4 helpers
- [ ] Produce `DeployManifest` and optionally write to
      `project_root / manifest_name`
- [ ] Export the function in `manifest/__init__.py` if needed

**Relevant Context**
- `flink_workshop/teardown_manifest.json` — shows `_noop` pattern and ordering
- `create_manifest_from_folder()` in `manifest.py` — existing function to follow as a
  structural model

**Status** `[ ] pending`

---

### Sub-Task 6 — Add `--dbt` flag to `manifest_cli.py`

**Intent**
Expose `create_manifest_from_dbt_folder()` through the existing Typer CLI with a
`--dbt` boolean flag. When `--dbt` is set, `--sql-dir` is used as the starting path for
`_find_dbt_project_root()`. The two modes are mutually exclusive.

**Expected Outcomes**
```bash
# Generate dbt-based manifest (dry-run)
uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming --dbt --dry-run

# Generate and write
uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming --dbt --overwrite

# Auto-detect: if --sql-dir ends in models/, walk up to find sl_dbt.yaml
uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming/models --dbt
```

**Todo List**
- [ ] Add `dbt: bool = typer.Option(False, "--dbt", ...)` to the `main()` command
- [ ] In `main()`: branch on `dbt` flag:
  - `True`: call `create_manifest_from_dbt_folder(project_root, ...)`
  - `False`: existing `create_manifest_from_folder(sql_dir, ...)`
- [ ] Resolve project root inside CLI using `_find_dbt_project_root(sql_dir)` and
      surface a clear error if not found
- [ ] Keep all existing options (`--prefix`, `--overwrite`, `--dry-run`) working in
      non-dbt mode; note that `--prefix` is ignored in dbt mode (prefix comes from
      `profiles.yml`)

**Relevant Context**
- `manifest_cli.py` — existing `main()` with Typer options

**Status** `[ ] pending`

---

### Sub-Task 7 — Tests

**Intent**
Add tests for the new dbt path covering: sanitize logic, project-root discovery,
node extraction, statement name generation, and end-to-end manifest creation using a
fixture based on `airbnb_streaming`.

**Expected Outcomes**
- `tests/test_manifest_dbt.py` exists with:
  - 3–4 `_dbt_sanitize_statement_name` unit tests
  - `_find_dbt_project_root` with a `tmp_path` fixture
  - `create_manifest_from_dbt_folder` end-to-end test against real
    `code/dbt/airbnb_streaming/` (or a minimal fixture copy)

**Todo List**
- [ ] Create `code/flink-sql/tools/tests/test_manifest_dbt.py`
- [ ] Parametrize sanitize test cases (underscores, long names, explicit statement_name)
- [ ] Add integration test using the real `airbnb_streaming` project root
- [ ] Run `uv run pytest tests/test_manifest_dbt.py` to confirm pass

**Relevant Context**
- `code/flink-sql/tools/tests/` — existing test directory
- `code/dbt/airbnb_streaming/` — real dbt project with `target/manifest.json`

**Status** `[ ] pending`

---

## Implementation Notes

### Statement Name Examples

For `airbnb_streaming` (project name has underscore → always gets hash):

| model | explicit `statement_name` | resulting Flink statement name |
|-------|--------------------------|-------------------------------|
| `src_hosts` | none | `dbt-airbnb-streaming-src-hosts-XXXXXX` |
| `dim_hosts_cleansed` | none | `dbt-airbnb-streaming-dim-hosts-cleansed-XXXXXX` |
| `fct_reviews` | none | `dbt-airbnb-streaming-fct-reviews-XXXXXX` |

For `flink_workshop` (models have explicit `statement_name`):

| model | explicit `statement_name` | resulting Flink statement name |
|-------|--------------------------|-------------------------------|
| `customers_faker` | `fw_crm_customers_faker` | `fw-crm-customers-faker-XXXXXX` |
| `customers_pk` | `fw_crm_customers_pk` | `fw-crm-customers-pk-XXXXXX` |

### Key Files

| File | Role |
|------|------|
| `code/flink-sql/tools/manifest/manifest.py` | Add Sub-Tasks 1–5 |
| `code/flink-sql/tools/manifest/manifest_cli.py` | Add Sub-Task 6 |
| `code/flink-sql/tools/tests/test_manifest_dbt.py` | Sub-Task 7 |
| `code/dbt/airbnb_streaming/target/manifest.json` | dbt artifact used as input |
| `code/dbt/airbnb_streaming/dbt_project.yml` | project name source |
| `code/dbt/airbnb_streaming/sl_dbt.yaml` | project root marker |
| `~/.dbt/profiles.yml` | `statement_name_prefix` source |
| `code/dbt/flink_workshop/teardown_manifest.json` | reference for `_noop` + group ordering |
