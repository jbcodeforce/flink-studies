# Plan: Skill — `flink-doc-sync`

## Overview

Create a Bob skill that validates documentation in `docs/` against the actual
codebase — checking that GitHub blob URL references to code files are still
reachable, that inline version strings are consistent, and that `mkdocs.yml`
navigation entries point to existing markdown files. Addresses the "weekly content
review / documentation testing" items in TASKS.md, which currently have no
automated support (`.github/workflows/` is empty).

**Scope**: Bob skill SKILL.md file only.

---

## Sub-Tasks

---

### Sub-Task 1 — Characterize reference patterns exhaustively

**Intent**: The skill must encode the actual reference patterns found in docs so the
agent knows exactly what to look for during a validation pass.

**Expected Outcomes**:
- Three primary reference patterns documented with concrete examples.
- List of the ~22 markdown files that contain code references.
- Edge cases noted (renamed files, moved demos, deleted demo folders).

**Todo List**:
1. Run a grep across `docs/` for `github.com/jbcodeforce/flink-studies` to capture all
   blob/tree URL references.
2. Run a grep for relative markdown links (`](../` or `](./`) to capture cross-doc
   references.
3. Run a grep for version strings (e.g. `1.20`, `7.8`, `2.1`) in docs markdown files
   to catalog inline version references.
4. Read `mkdocs.yml` nav section to list all `page: path.md` entries and confirm each
   file exists.
5. Summarize findings: count of each pattern type, highest-risk files.

**Relevant Context**:
- `docs/` — all markdown documentation
- `mkdocs.yml` — navigation structure
- `TASKS.md` lines 105–115 — doc maintenance tasks (no CI yet)
- `.github/workflows/` — currently empty (no automation)

**Status**: [x] done

---

### Sub-Task 2 — Write the SKILL.md

**Intent**: Author the skill so Bob can run a structured documentation audit,
reporting broken references and version inconsistencies with actionable fix guidance.

**Expected Outcomes**:
- `~/.bob/skills/flink-doc-sync/SKILL.md` exists.
- Skill triggers when user asks to validate docs, check for broken links, audit
  documentation, or run a doc sync pass.
- Skill produces a structured report: broken URLs, missing files, version mismatches,
  stale nav entries.

**Todo List**:
1. Create directory `~/.bob/skills/flink-doc-sync/`.
2. Write `SKILL.md` with frontmatter (`name`, `description`, `triggers`).
3. Document **Check 1 — GitHub blob/tree URL validation**:
   - Grep `docs/**/*.md` for `github.com/jbcodeforce/flink-studies/blob/master/` and
     `github.com/jbcodeforce/flink-studies/tree/master/`.
   - Strip the prefix to get a repo-relative path (e.g. `code/flink-sql/00-basic-sql/README.md`).
   - Check whether that path exists in the local workspace with `list_files` or `glob`.
   - Report: file, line number, referenced path, status (exists / missing).
4. Document **Check 2 — mkdocs.yml nav validation**:
   - Parse all `- page: docs/<path>.md` entries from `mkdocs.yml`.
   - Verify each file exists under `docs/`.
   - Report orphaned nav entries and markdown files not in nav.
5. Document **Check 3 — inline version string consistency**:
   - Grep docs for version patterns: `flink-\d+\.\d+`, `cp-\d+\.\d+`, `kafka_\d+\.\d+`.
   - Cross-reference against the canonical versions in `deployment/docker/docker-compose.yaml`
     and `pyproject.toml` (root).
   - Flag any doc version that differs from the deployed version.
6. Document **report format**: a markdown table per check with columns
   `File | Line | Reference | Status | Suggested Fix`.
7. Document **fix guidance** for each check type:
   - Broken blob URL: update URL or remove link if file was deleted/moved.
   - Orphaned nav entry: add the missing `.md` file or remove the nav entry.
   - Version mismatch: update doc string to match canonical version source.
8. Note: this skill does NOT check external URLs (Confluent docs, Flink official) —
   scope is limited to intra-repo references and version strings.

**Relevant Context**:
- Primary reference files: `docs/coding/flink-sql-2.md`, `docs/coding/getting-started.md`,
  `docs/cookbook/job_lifecycle.md`, `docs/architecture/kafka.md`
- `docs/mkdocs.yml` — nav source of truth
- `deployment/docker/docker-compose.yaml` — canonical CP version (7.8.0)
- `pyproject.toml` (root) — canonical Flink Python version (1.20.1)

**Status**: [x] done

---

### Sub-Task 3 — Register the skill with Bob

**Intent**: Make the skill discoverable.

**Expected Outcomes**:
- Skill appears in Bob's available skills list under `flink-doc-sync`.

**Todo List**:
1. Confirm file path matches Bob's convention (`~/.bob/skills/<skill-name>/SKILL.md`).
2. Verify skill loads correctly via `use_skill`.

**Status**: [x] done — skill placed at `.bob/skills/flink-doc-sync/` (workspace scope,
auto-discovered). Audit script at `.bob/skills/flink-doc-sync/doc_sync_audit.py`.
First run found 46 broken URL references across 13 doc files; 0 nav issues; 0 version mismatches.

---
