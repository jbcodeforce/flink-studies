# manifest — Deploy manifest generator

Generates `deploy_manifest.json` for Confluent Cloud Flink statement deploy/undeploy/teardown workflows.

Two modes:

| Mode | Source | Use when |
|------|--------|----------|
| **SQL folder** (default) | Raw `.sql` files on disk | Standard Flink SQL demos under `code/flink-sql/` |
| **dbt mode** (`--dbt`) | `target/manifest.json` produced by `dbt run` | dbt-confluent projects under `code/dbt/` |

The generated `deploy_manifest.json` is consumed by [`cc_deploy`](../cc_deploy/) — both modes produce a structurally identical manifest, so all deploy/undeploy/drop-tables commands work unchanged.

---

## Setup

```sh
cd code/flink-sql/tools

# Base install (SQL-folder mode only)
uv sync

# With dbt support
uv sync --extra dbt
```

---

## SQL folder mode

### Generate a manifest

```sh
cd code/flink-sql/tools

# Preview without writing
uv run python -m manifest.manifest_cli --sql-dir ../11-puzzles/my_demo --dry-run

# Write deploy_manifest.json to the demo folder
uv run python -m manifest.manifest_cli --sql-dir ../11-puzzles/my_demo

# Override the statement name prefix
uv run python -m manifest.manifest_cli --sql-dir ../11-puzzles/my_demo --prefix my-demo

# Overwrite an existing manifest
uv run python -m manifest.manifest_cli --sql-dir ../11-puzzles/my_demo --overwrite
```

### File-to-group classification

SQL files are grouped by naming convention:

| Filename pattern | Group |
|------------------|-------|
| `ddl.*.sql` | `ddl` |
| `insert_*.sql`, `insert.*.sql`, `dml.insert_*.sql`, `dml.insert.*.sql` | `data` |
| `dml.update_*.sql`, `scenario.*.sql` | `scenario` |
| any other `dml.*.sql` | `pipeline` |
| anything else | `pipeline` |

Files under `tests/` are included only when classified as `data` (seed inserts). All other test fixtures are skipped.

### Statement name format

```
{prefix}-{group}-{file-slug}                   # top-level files
{prefix}-{folder-slug}-{group}-{file-slug}     # nested files
```

Underscores in folder and file names are converted to hyphens.

### Default deploy/undeploy order

```
deploy_all:   ddl → pipeline → data
undeploy_all: scenario → data → pipeline
```

`drop_tables` is inferred from `CREATE TABLE` statements in DDL files (reverse filename order — dependents first).

### Example manifest

```json
{
  "user_agent": "cc-sql-tools/0.1",
  "deploy_all": ["ddl", "pipeline"],
  "undeploy_all": ["pipeline"],
  "drop_tables": ["enriched_orders", "orders"],
  "drop_statement_prefix": "my-demo-drop",
  "groups": {
    "ddl": [
      {"name": "my-demo-ddl-orders",          "file": "ddl.orders.sql"},
      {"name": "my-demo-ddl-enriched-orders",  "file": "ddl.enriched_orders.sql"}
    ],
    "pipeline": [
      {"name": "my-demo-pipeline-enrich", "file": "dml.enrich.sql"}
    ]
  }
}
```

---

## dbt mode

Generates a manifest from a **dbt-confluent** project. Instead of scanning SQL files on disk, it reads `target/manifest.json` — the artifact produced by `dbt run` or `dbt compile` — and reconstructs the exact Flink statement names using the same `sanitize_statement_name` algorithm as the dbt-confluent adapter.

Requires `dbt-confluent` installed (`uv sync --extra dbt`) and a prior `dbt run` or `dbt compile` in the project.

### Auto-discovery

The project root is resolved automatically from `--sql-dir`:

1. `--sql-dir` itself contains `dbt_project.yml` → use it directly.
2. Walk up parent directories looking for `sl_dbt.yaml` (the shift-left project marker).

So you can point `--sql-dir` at the project root **or** at any subdirectory such as `models/`.

### Generate a manifest

```sh
cd code/flink-sql/tools

# Preview (dry-run)
uv run python -m manifest.manifest_cli \
  --sql-dir ../../dbt/airbnb_streaming --dbt --dry-run

# Write deploy_manifest.json to the dbt project root
uv run python -m manifest.manifest_cli \
  --sql-dir ../../dbt/airbnb_streaming --dbt

# From a models/ subdirectory (auto-discovers project root)
uv run python -m manifest.manifest_cli \
  --sql-dir ../../dbt/airbnb_streaming/models --dbt --dry-run

# Overwrite an existing manifest
uv run python -m manifest.manifest_cli \
  --sql-dir ../../dbt/airbnb_streaming --dbt --overwrite
```

### Statement name reconstruction

The statement name for each model follows the dbt-confluent adapter formula:

```
sanitize( {statement_name_prefix}{project_name}-{model_name} )
```

Where `sanitize` means: lowercase → replace `[^a-z0-9-]` with `-` → if any replacement occurred **or** the name exceeds 100 chars, append `-{first-6-chars-of-MD5(original)}`.

When a model sets `statement_name` explicitly in its `{{ config(...) }}` block, that value is used as the input to `sanitize` instead.

`statement_name_prefix` is read from `~/.dbt/profiles.yml` using the profile declared in `dbt_project.yml`. Defaults to `"dbt-"` if the file is missing or the key is absent.

**Examples for `airbnb_streaming` (prefix `dbt-`, project `airbnb_streaming`):**

| model | statement name |
|-------|---------------|
| `src_hosts` | `dbt-airbnb-streaming-src-hosts-430c08` |
| `dim_hosts_cleansed` | `dbt-airbnb-streaming-dim-hosts-cleansed-892aed` |
| `fct_reviews` | `dbt-airbnb-streaming-fct-reviews-d04f43` |

The 6-char suffix is the MD5 hash of the original (pre-sanitize) name, so it is deterministic and stable across runs.

### Model-to-group mapping

Models are grouped by the deepest parent directory segment that matches a known layer name:

| path segment | manifest group |
|--------------|----------------|
| `sources` | `sources` |
| `dimensions` | `dimensions` |
| `facts` | `facts` |
| `marts` | `marts` |
| seed nodes | `seeds` |
| anything else | `pipeline` |

Example: `models/user_reviews/sources/src_hosts.sql` → group `sources`.

### Deploy/undeploy order

```
deploy_all:   seeds → sources → dimensions → pipeline → facts → marts
undeploy_all: marts → facts → pipeline → dimensions → sources → seeds
```

Only groups that are actually present appear in the lists.

### `drop_tables` scope

`drop_tables` covers the full teardown in dependency-first order:

1. **dbt model and seed tables** — in undeploy group order (facts/marts first, seeds last)
2. **Raw source tables** — from `models/**/sources.yaml` (Kafka topics that dbt reads but does not own), appended after all model/seed tables

### `file` field

Every `StatementRef.file` is set to `"_noop"` in dbt mode because dbt owns deployment. The manifest is used only for undeploy (`cc_deploy undeploy`) and drop-tables (`cc_deploy drop-tables`).

### Example manifest (airbnb_streaming)

```json
{
  "user_agent": "cc-sql-tools/0.1",
  "groups": {
    "seeds": [
      {"name": "dbt-airbnb-streaming-seed-full-moon-dates-4f973a", "file": "_noop"}
    ],
    "sources": [
      {"name": "dbt-airbnb-streaming-src-hosts-430c08",     "file": "_noop"},
      {"name": "dbt-airbnb-streaming-src-listings-99b825",  "file": "_noop"},
      {"name": "dbt-airbnb-streaming-src-reviews-641a06",   "file": "_noop"}
    ],
    "dimensions": [
      {"name": "dbt-airbnb-streaming-dim-hosts-cleansed-892aed",       "file": "_noop"},
      {"name": "dbt-airbnb-streaming-dim-listings-cleansed-db4211",    "file": "_noop"},
      {"name": "dbt-airbnb-streaming-dim-listings-with-hosts-b8b475",  "file": "_noop"}
    ],
    "facts": [
      {"name": "dbt-airbnb-streaming-fct-reviews-d04f43",          "file": "_noop"},
      {"name": "dbt-airbnb-streaming-fct-listing-pricing-d8abce",  "file": "_noop"},
      {"name": "dbt-airbnb-streaming-fct-review-summary-806037",   "file": "_noop"},
      {"name": "dbt-airbnb-streaming-fct-host-performance-fefd70", "file": "_noop"},
      {"name": "dbt-airbnb-streaming-fct-listing-activity-4f2b77", "file": "_noop"}
    ]
  },
  "deploy_all":   ["seeds", "sources", "dimensions", "facts"],
  "undeploy_all": ["facts", "dimensions", "sources", "seeds"],
  "drop_tables": [
    "fct_host_performance", "fct_review_summary", "fct_listing_activity",
    "fct_reviews", "fct_listing_pricing",
    "dim_listings_with_hosts", "dim_listings_cleansed", "dim_hosts_cleansed",
    "src_reviews", "src_listings", "src_hosts",
    "seed_full_moon_dates",
    "raw_hosts", "raw_listings", "raw_reviews", "raw_full_moon_dates"
  ],
  "drop_statement_prefix": "dbt-airbnb-streaming-drop-78c08b"
}
```

---

## Using the manifest with cc_deploy

Once `deploy_manifest.json` is generated (in either mode):

```sh
cd code/flink-sql/tools

# Stop all streaming statements (dbt mode: undeploys by statement name only, no file deploy)
uv run python -m cc_deploy.deploy_flink_statements \
  --sql-dir ../../dbt/airbnb_streaming undeploy --group all

# Drop all tables (models + seeds + raw sources)
uv run python -m cc_deploy.deploy_flink_statements \
  --sql-dir ../../dbt/airbnb_streaming drop-tables

# Full teardown (undeploy then drop)
uv run python -m cc_deploy.deploy_flink_statements \
  --sql-dir ../../dbt/airbnb_streaming undeploy --group all
uv run python -m cc_deploy.deploy_flink_statements \
  --sql-dir ../../dbt/airbnb_streaming drop-tables
```

---

## Python API

```python
from pathlib import Path
from manifest.manifest import (
    create_manifest_from_folder,       # SQL-folder mode
    create_manifest_from_dbt_folder,   # dbt mode
    load_manifest,
    write_manifest,
)

# SQL-folder mode
manifest = create_manifest_from_folder(
    Path("../11-puzzles/my_demo"),
    prefix="my-demo",
    write=True,
    overwrite=True,
)

# dbt mode (requires uv sync --extra dbt)
manifest = create_manifest_from_dbt_folder(
    Path("../../dbt/airbnb_streaming"),
    write=True,
    overwrite=True,
)

# Load an existing manifest
manifest = load_manifest(Path("deploy_manifest.json"))
print(manifest.deploy_all)
print(manifest.drop_tables)
```

---

## CLI reference

```
uv run python -m manifest.manifest_cli [OPTIONS]

Options:
  --sql-dir PATH     Folder with Flink SQL files, or dbt project root for --dbt  [required]
  --prefix TEXT      Statement name prefix (SQL mode only; default: folder name)
  --dbt              Generate from a dbt-confluent project (requires --extra dbt)
  --dry-run          Print JSON without writing a file
  --overwrite        Replace an existing deploy_manifest.json
  --help             Show this message and exit.
```
