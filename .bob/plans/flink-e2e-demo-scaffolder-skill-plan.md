# Plan: Skill — `flink-e2e-demo-scaffolder`

## Overview

Create a Bob skill that guides the agent through scaffolding a brand-new e2e demo,
building on the existing `demo_mgr_cli.py` (`fla init`) and
`assistants/jump_start_demo/` tooling. The skill bridges the two tools: `fla init`
creates bare platform directories; `jump-start init` fills in SQL, manifest, and
producer templates. The skill tells Bob when to use each, what arguments to supply,
and how to wire the output to the rest of the repo (README table, tracking matrix,
docs navigation).

**Scope**: Bob skill SKILL.md file only.

---

## Sub-Tasks

---

### Sub-Task 1 — Map the end-to-end scaffolding workflow

**Intent**: Understand the exact command sequence and outputs of `demo_mgr_cli` and
`jump_start_demo` so the skill can provide a reliable, step-by-step guide.

**Expected Outcomes**:
- `demo_mgr_cli.py` CLI interface confirmed (commands, flags, what it creates).
- `jump_start_demo` CLI interface confirmed (`init`, `validate`, `manifest` subcommands
  and their flags).
- Template outputs of `jump-start init` documented (which files are generated).
- Overlap and hand-off point between the two tools clarified.

**Todo List**:
1. Read `tools/demo_mgr_cli.py` in full to confirm `init` command signature and
   directory output.
2. Read `assistants/jump_start_demo/tools/cli.py` to confirm `jump-start` subcommands
   and arguments.
3. Read `assistants/jump_start_demo/tools/jump_start/scaffold.py` to confirm what
   `DemoSpec` generates.
4. List `assistants/jump_start_demo/templates/` to enumerate all Jinja templates
   (SQL, Makefile, docker-compose, producers, README, manifest).
5. Check `assistants/jump_start_demo/reference/` for conventions encoded in deep docs
   (especially `deploy-manifest.md`).
6. Read one complete generated demo tree (e.g. `e2e-demos/dedup-demo/`) to confirm
   the final expected layout.

**Relevant Context**:
- `tools/demo_mgr_cli.py` — `fla init --project-type e2e --platform cc-flink`
- `assistants/jump_start_demo/tools/cli.py` — `jump-start init/validate/manifest`
- `assistants/jump_start_demo/tools/jump_start/scaffold.py` — `DemoSpec` dataclass
- `e2e-demos/dedup-demo/` — reference demo with complete layout
- `code/flink-sql/README.md` — tracking matrix to update after scaffold

**Status**: [ ] pending

---

### Sub-Task 2 — Write the SKILL.md

**Intent**: Author the skill so Bob can scaffold a new e2e demo interactively,
collecting the right inputs, invoking the right tools in order, and completing all
post-scaffold wiring steps.

**Expected Outcomes**:
- `~/.bob/skills/flink-e2e-demo-scaffolder/SKILL.md` exists.
- Skill triggers when user asks to create, scaffold, or add a new e2e demo.
- Skill walks through: naming → platform selection → tool invocation → post-scaffold
  checklist.

**Todo List**:
1. Create directory `~/.bob/skills/flink-e2e-demo-scaffolder/`.
2. Write `SKILL.md` with frontmatter (`name`, `description`, `triggers`).
3. Document the **information-gathering step**: ask the user for demo name, business
   scenario, platforms to support (`cc-flink`, `oss`, `cp-flink`, or all), and whether
   a Kafka producer is needed.
4. Document **Step 1 — bare scaffold** using `fla init`:
   ```bash
   cd e2e-demos/<demo-name>
   uv run python tools/demo_mgr_cli.py init . \
     --project-type e2e \
     --platform <platform>
   ```
5. Document **Step 2 — full template generation** using `jump-start init`:
   ```bash
   cd assistants/jump_start_demo
   uv run jump-start init \
     --name <demo-name> \
     --scenario "<description>" \
     --platform cccloud   # or oss / cp-flink
   ```
6. Document **Step 3 — manifest generation**:
   ```bash
   uv run python -m cc_deploy.create_deploy_manifest \
     --sql-dir e2e-demos/<demo-name>/cccloud/flink-sql/ \
     --prefix <demo-prefix>
   ```
7. Document **Step 4 — validation**:
   ```bash
   cd assistants/jump_start_demo
   uv run jump-start validate --demo e2e-demos/<demo-name>
   ```
8. Document **Step 5 — post-scaffold wiring**:
   - Add demo row to tracking matrix in `code/flink-sql/README.md`.
   - Add demo entry to `e2e-demos/README.md` table.
   - Add doc page stub to `docs/` and register in `mkdocs.yml` nav.
9. Note the distinction: use `jump_start` agent mode for interactive LLM-driven design
   of SQL schemas; use CLI mode for deterministic generation when schema is already known.

**Relevant Context**:
- `e2e-demos/README.md` — demo table to update
- `code/flink-sql/README.md` — completion matrix to update
- `docs/mkdocs.yml` — nav to update when adding a new doc page
- `assistants/jump_start_demo/reference/` — conventions reference docs

**Status**: [ ] pending

---

### Sub-Task 3 — Register the skill with Bob

**Intent**: Make the skill discoverable.

**Expected Outcomes**:
- Skill appears in Bob's available skills list under `flink-e2e-demo-scaffolder`.

**Todo List**:
1. Confirm file path matches Bob's convention (`~/.bob/skills/<skill-name>/SKILL.md`).
2. Verify skill loads correctly via `use_skill`.

**Relevant Context**:
- Existing skills in `~/.bob/skills/` for format reference.

**Status**: [ ] pending

---
