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

Build the absolute project root based on project type:

| Project type | Base directory | Example full path |
|---|---|---|
| `e2e` | `e2e-demos/` | `e2e-demos/fraud-detection` |
| `study` | `code/flink-sql/` | `code/flink-sql/16-pattern-matching` |

---

## Step 3 — Run the CLI

Execute [`tools/demo_mgr_cli.py`](tools/demo_mgr_cli.py) via `uv run` from the `tools/` directory:

```bash
cd tools && uv run demo_mgr_cli.py init <project_root> --project-type <e2e|study> --platform <cc-flink|cp-flink|oss|all>
```

Concrete examples:

```bash
# New e2e demo for all platforms
cd tools && uv run demo_mgr_cli.py init ../e2e-demos/fraud-detection --project-type e2e --platform all

# New flink-sql study for Confluent Cloud only
cd tools && uv run demo_mgr_cli.py init ../code/flink-sql/16-pattern-matching --project-type study --platform cc-flink
```

Use `execute_command` with `cwd` set to `tools`:

```
execute_command(
  command = "uv run demo_mgr_cli.py init <resolved_path> --project-type <type> --platform <platform>",
  cwd     = "tools"
)
```

where `<resolved_path>` is relative to the workspace root (e.g. `../e2e-demos/fraud-detection`).

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

## Step 6 — Report

Tell the user:
- Full path created
- Platform sub-folders scaffolded
- Next suggested step (e.g. "Add your SQL files under `cc-flink/` and fill in `README.md`")
