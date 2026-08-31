# Plan: Skill — `flink-demo-deployment-standardizer`

## Overview

Create a Bob skill that guides the agent through migrating an e2e demo from manual
Confluent CLI / Terraform deployment to the standardized `cc_deploy` toolchain
(`deploy_flink_statements.py` + `deploy_manifest.json` + Makefile delegation).

Currently 14 of 18 e2e demos still rely on manual steps or ad-hoc scripts. The skill
provides the agent with the exact conventions, file locations, manifest format, and
Makefile delegation pattern so each migration is consistent and reviewable.

**Scope**: Bob skill SKILL.md file only. No changes to application code.

---

## Sub-Tasks

---

### Sub-Task 1 — Inventory existing standards

**Intent**: Collect the concrete conventions the skill must encode — manifest format,
Makefile delegation pattern, SQL naming, directory layout — from demos that already use
`cc_deploy` correctly.

**Expected Outcomes**:
- List of 4 reference demos that already use `cc_deploy` identified with their exact
  file paths.
- Manifest JSON schema documented (fields: `user_agent`, `deploy_all`, `undeploy_all`,
  `drop_tables`, `drop_statement_prefix`, `groups`).
- Makefile delegation snippet confirmed.
- SQL naming convention confirmed (`ddl.*`, `dml.insert_*`, `dml.*`).

**Todo List**:
1. Read `code/flink-sql/README.md` completion matrix to identify the 4 standardized demos.
2. Read `deploy_manifest.json` from one reference demo (e.g. `e2e-demos/dedup-demo/cccloud/`).
3. Read the delegating `Makefile` from that same demo.
4. Read `code/flink-sql/tools/cc_deploy/deploy_flink_statements.py` (first 80 lines) to confirm CLI interface.
5. Read `assistants/jump_start_demo/` README or CLI entrypoint to understand where it overlaps.

**Relevant Context**:
- `code/flink-sql/README.md` — completion matrix
- `code/flink-sql/tools/cc_deploy/deploy_flink_statements.py` — deployment engine
- `code/flink-sql/tools/cc_deploy/create_deploy_manifest.py` — manifest auto-generator
- `e2e-demos/<reference-demo>/cccloud/` — reference demos

**Status**: [ ] pending

---

### Sub-Task 2 — Write the SKILL.md

**Intent**: Author the skill file so Bob knows exactly how to migrate a demo when asked.

**Expected Outcomes**:
- `~/.bob/skills/flink-demo-deployment-standardizer/SKILL.md` exists.
- Skill is triggered when the user asks to standardize, migrate, or upgrade a demo's
  deployment to use `cc_deploy`.
- Skill encodes: audit checklist, manifest generation command, Makefile delegation
  snippet, SQL renaming rules, and validation steps.

**Todo List**:
1. Create directory `~/.bob/skills/flink-demo-deployment-standardizer/`.
2. Write `SKILL.md` with frontmatter (`name`, `description`, `triggers`).
3. Document the **audit step**: how to detect whether a demo already uses `cc_deploy`
   (presence of `deploy_manifest.json`, delegation line in Makefile).
4. Document the **SQL naming step**: rename any non-standard SQL files to the
   `ddl.*` / `dml.insert_*` / `dml.*` convention.
5. Document the **manifest generation step**:
   ```bash
   uv run python -m cc_deploy.create_deploy_manifest \
     --sql-dir <demo>/cccloud/flink-sql/ \
     --prefix <demo-prefix>
   ```
6. Document the **Makefile delegation snippet** to add:
   ```makefile
   TOOLS := $(abspath ../../../code/flink-sql/tools)
   SQL_DIR := $(abspath .)
   deploy undeploy drop-tables:
       $(MAKE) -C $(TOOLS) SQL_DIR=$(SQL_DIR) $@
   ```
7. Document the **validation step**: run `make deploy --group ddl` in dry-run or
   confirm manifest groups with `python -m cc_deploy.deploy_flink_statements groups`.
8. Document how to update the completion matrix in `code/flink-sql/README.md`.

**Relevant Context**:
- `assistants/jump_start_demo/` — overlapping scaffold tool (skill should reference it
  for net-new demos; this skill focuses on migration of existing demos)
- `tools/demo_mgr_cli.py` — lightweight scaffold CLI (`fla init`)

**Status**: [ ] pending

---

### Sub-Task 3 — Register the skill with Bob

**Intent**: Make the skill discoverable in Bob's skill list.

**Expected Outcomes**:
- Skill appears in Bob's available skills list.
- `use_skill` with `skill_name: "flink-demo-deployment-standardizer"` loads it correctly.

**Todo List**:
1. Confirm the skill file path matches Bob's skill discovery convention
   (`~/.bob/skills/<skill-name>/SKILL.md`).
2. Test by asking Bob to list available skills and verify it appears.

**Relevant Context**:
- Existing skills in `~/.bob/skills/` for naming/format reference.

**Status**: [ ] pending

---
