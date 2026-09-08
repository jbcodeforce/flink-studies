---
name: flink-scaffold
description: >
  Use when the user wants to create a new e2e-demo under `e2e-demos/` or a new
  study/lab under `code/flink-sql/`. Trigger phrases: "create a demo",
  "scaffold a demo", "new e2e demo", "create a study", "new flink-sql study",
  "add a flink-sql exercise", "scaffold a flink study", "initialize a demo",
  "create e2e-demos", "create studies under flink-sql".
---

# flink-scaffold

Scaffold a new e2e demo or flink-sql study using the [`tools/demo_mgr_cli.py`](tools/demo_mgr_cli.py) CLI.

## When to use

- The user asks to create a new demo in `e2e-demos/`
- The user asks to create a new study / exercise under `code/flink-sql/`

---

## Step 1 — Gather required information

Ask the user (using `ask_followup_question`) for anything not already stated:

| What to ask | Choices / notes |
|---|---|
| **Project type** | `e2e` for an end-to-end demo, `study` for a flink-sql code study |
| **Folder / slug name** | e.g. `16-pattern-matching` (for study) or `fraud-detection` (for demo). Must be URL-safe, lowercase, dashes allowed. |
| **Platform** | `cc-flink` (Confluent Cloud), `cp-flink` (Confluent Platform), `oss` (Apache Flink OSS), or `all` (all three sub-folders) |

Do **not** ask for things already provided in the user's message.

---

## Step 2 — Resolve the target path

Build the project root path based on project type:

| Project type | Base directory | Example full path |
|---|---|---|
| `e2e` | `e2e-demos/` | `e2e-demos/fraud-detection` |
| `study` | `code/flink-sql/` | `code/flink-sql/16-pattern-matching` |

The CLI lives at the **workspace root** under `tools/`, not under `code/flink-sql/tools/`.
Always run it with `cwd = "tools"` (workspace-root-relative).

---

## Step 3 — Run the CLI

#### IMPORTANT — correct invocation

The CLI has **no `init` subcommand**. `project_root` is a bare positional argument.
The correct form is:

```bash
uv run python demo_mgr_cli.py <project_root_relative_to_tools> --project-type <e2e|study> --platform <cc-flink|cp-flink|oss|all>
```

Run with `execute_command`, `cwd = "tools"`:

```
execute_command(
  command = "uv run python demo_mgr_cli.py <path_relative_to_tools> --project-type <type> --platform <platform>",
  cwd     = "tools"
)
```

Because `cwd` is `tools/` (workspace root), paths for studies and demos must be prefixed
with `../`:

| Project type | Example command from `cwd=tools` |
|---|---|
| `study` | `uv run python demo_mgr_cli.py ../code/flink-sql/16-pattern-matching --project-type study --platform cc-flink` |
| `e2e` | `uv run python demo_mgr_cli.py ../e2e-demos/fraud-detection --project-type e2e --platform all` |

#### If the CLI fails with a SyntaxError on line 74

There is a known typo in [`tools/demo_mgr_cli.py:74`](tools/demo_mgr_cli.py:74) — an extra
quote in the `cc-dbt` case. Fix it before running:

```python
# Wrong (original):
_write(project_root / "cc-dbt" / "".gitkeep", "")
# Correct:
_write(project_root / "cc-dbt" / ".gitkeep", "")
```

---

## Step 4 — Verify the output

After the command succeeds, list the created directory with `list_files` and confirm the expected
structure to the user:

**`study` layout (e.g. `code/flink-sql/16-pattern-matching/`):**

```
16-pattern-matching/
  cc-flink/       (if platform = cc-flink or all)
  cp-flink/       (if platform = cp-flink or all)
  oss/            (if platform = oss or all)
  docs/
  README.md
```

**`e2e` layout (e.g. `e2e-demos/fraud-detection/`):**

```
fraud-detection/
  cc-flink/       (if platform = cc-flink or all)
  cp-flink/       (if platform = cp-flink or all)
  oss/            (if platform = oss or all)
  IaC/
  docs/
  README.md
```

---

## Step 5 — Seed README.md

Open the generated `README.md` and replace the stub `# ` heading with:

```markdown
# <Slug title-cased>

> One-sentence description of what this demo / study covers.

## Prerequisites

- Docker (for OSS / CP-Flink) or Confluent Cloud account
- Apache Flink <version> or Confluent Cloud Flink

## How to run

_TODO_
```

Use `apply_diff` or `search_and_replace` to do this minimally.

---

## Step 6 — Generate `deploy_manifest.json`

After writing SQL files into the platform sub-folder (e.g. `cc-flink/`), generate the
deployment manifest automatically using `manifest_cli`. This tool lives in
`code/flink-sql/tools/` and paths are relative to that directory.

```bash
# Preview without writing (dry-run)
uv run python -m manifest.manifest_cli --sql-dir ../<slug>/cc-flink --dry-run

# Write deploy_manifest.json
uv run python -m manifest.manifest_cli --sql-dir ../<slug>/cc-flink
```

Run with `execute_command`, `cwd = "code/flink-sql/tools"`.

The CLI infers groups from SQL file naming conventions:

| File name pattern | Group assigned |
|---|---|
| `ddl.*.sql` | `ddl` |
| `dml.insert_*.sql` | `data` |
| `dml.update_*.sql` | `scenario` |
| all other `dml.*.sql` | `pipeline` |

#### After generation — always patch these fields

The auto-generated manifest needs manual corrections before use:

| Field | Issue | Correct value |
|---|---|---|
| `user_agent` | Generic default | `"flink-studies-<slug>/0.1"` |
| `drop_tables` | Order may be wrong | Must be **sinks first**, sources last to avoid FK/dependency errors |
| `drop_statement_prefix` | Generic default | `"<prefix>-drop"` matching the study prefix |
| `deploy_all` | May include `pipeline` before `data` | Must be `["ddl", "data", "pipeline"]` |
| `undeploy_all` | May include `data` | Should be `["pipeline"]` only — data inserts are not long-running statements |
| Statement names | May have redundant double segments | Verify names like `cc-flink-pipeline-pipeline-foo` and simplify |

Write the corrected manifest with `write_file` after reviewing the dry-run output.

---

## Step 7 — Write the Makefile

Create a `Makefile` at the study root that delegates to `tools/Makefile`. Copy this pattern
exactly (it is identical across all modern studies):

```makefile
TOOLS := $(abspath ../tools)
DEMO  := $(abspath cc-flink)

.PHONY: sync deploy undeploy drop-tables deploy-% undeploy-%

sync:
	$(MAKE) -C $(TOOLS) sync

deploy:
	$(MAKE) -C $(TOOLS) deploy SQL_DIR=$(DEMO)

undeploy:
	$(MAKE) -C $(TOOLS) undeploy SQL_DIR=$(DEMO)

drop-tables:
	$(MAKE) -C $(TOOLS) drop-tables SQL_DIR=$(DEMO)

deploy-%:
	$(MAKE) -C $(TOOLS) deploy-$* SQL_DIR=$(DEMO)

undeploy-%:
	$(MAKE) -C $(TOOLS) undeploy-$* SQL_DIR=$(DEMO)
```

**`TOOLS` always points to `../tools`** (the shared `code/flink-sql/tools/` directory).
**`DEMO` points to `./cc-flink`** (adjust to `./cp-flink` or `./oss` as needed).

Do **not** use the older pattern from `05-changelog/Makefile` that hard-codes credentials
and calls `confluent flink statement create` directly — that pattern is deprecated.

---

## Step 8 — Report

Tell the user:
- Full path created
- Platform sub-folders scaffolded
- Files created (DDL, DML, manifest, Makefile, README)
- Deployment workflow:
  ```sh
  make sync          # once: install tool deps
  make deploy-ddl    # create tables/topics
  make deploy-data   # seed data
  make deploy-pipeline  # start streaming statements
  make undeploy      # stop statements
  make drop-tables   # drop tables
  ```
