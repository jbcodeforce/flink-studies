---
name: flink-doc-sync
description: >
  Use when the user wants to validate documentation against the codebase in the
  flink-studies repo — checking that GitHub URL references point to existing
  files, that mkdocs.yml nav entries resolve, and that inline version strings
  are consistent with the deployed versions. Trigger phrases: "check docs",
  "validate documentation", "broken links in docs", "doc sync", "doc audit",
  "doc drift", "update docs", "docs out of date".
---

# flink-doc-sync

Run a structured audit of `docs/` against the live codebase and report every
discrepancy with actionable fix guidance.

## When to use

- Before a docs release or MkDocs site rebuild.
- After restructuring code folders (renamed demos, moved SQL files).
- As part of the monthly maintenance cycle described in `TASKS.md`.
- When a user reports a broken link in the published docs site.

## Scope (what this skill checks)

| Check | What it validates |
|-------|------------------|
| **1 — GitHub URL references** | Every `github.com/jbcodeforce/flink-studies/blob/master/` and `/tree/master/` URL in docs points to a path that exists in the local workspace. |
| **2 — mkdocs.yml nav** | Every file listed in the `nav:` section of `mkdocs.yml` exists under `docs/`. |
| **3 — Inline CP version strings** | CP broker image tags referenced in docs match the canonical version in `deployment/docker/docker-compose.yaml`. |

**Out of scope:** external URLs (Confluent docs, Apache Flink site, GitHub external repos),
image/diagram files, cross-doc relative links, or Java/Python version strings.

---

## Step 1 — Run the audit

The primary tool is [`tools/doc_sync.py`](tools/doc_sync.py). Run it from inside the
`tools/` directory:

```bash
cd tools

# Report only (exit 1 if issues found)
uv run doc_sync.py audit

# Report + auto-fix deterministic issues (missing code/ prefix, version mismatches)
uv run doc_sync.py audit --fix

# Report + auto-fix + LLM suggestions for ambiguous issues (local Ollama by default)
uv run doc_sync.py audit --fix --agent

# Use a different model or remote endpoint
uv run doc_sync.py audit --agent --model gpt-4o --base-url https://api.openai.com/v1

# Show canonical versions extracted from the repo
uv run doc_sync.py versions
```

The tool prints rich tables to the terminal — one per check — and exits with code `1`
if any issues remain after fixes, `0` if clean.

> **Fallback:** A stdlib-only version of the audit script also exists at
> `.bob/skills/flink-doc-sync/doc_sync_audit.py` (no dependencies, markdown output).
> Use it when the `tools/` venv is not available.

---

## Step 2 — Understand the output columns

Each table row has:
- **File** — the doc file containing the issue
- **Line** — exact line number
- **Reference** — the broken path or version string
- **Note** — root cause or suggested fix
- **Fix?** — `⚡ auto` (will be fixed by `--fix`), `✗ manual` (needs human judgment), `✔ fixed` (already applied)

---

## Step 3 — Triage `✗ manual` issues

These are issues `--fix` cannot resolve automatically. Apply the rules below:

### Check 1 — Broken GitHub URL references (manual)

| Root cause | Action |
|-----------|--------|
| **Subfolder not yet created** — demo or study planned but not added | Do not fabricate the path. Add a `<!-- TODO: create this folder -->` comment in the doc, or remove the link. |
| **Old deleted folder** (`kafka-flink-demo/`) | Replace with the current path or remove the link. |
| **File renamed/moved** | Use `glob` or `grep` to find the new location, then update the URL. |

For each manual fix, use `search_and_replace` on the exact URL.

### Check 2 — Orphaned mkdocs.yml nav entries

- If the `.md` file was deleted: remove the nav entry from `mkdocs.yml`.
- If the `.md` file was not yet created: create a stub file with a `# Title` heading.

### Check 3 — Version strings (all auto-fixable)

CP broker version mismatches are fixed automatically by `--fix`. No manual triage needed.

---

## Step 4 — Re-run to confirm

After manual edits, re-run to confirm the count drops:

```bash
cd tools && uv run doc_sync.py audit
```

---

## Step 5 — Report

Present a summary:

```
Auto-fixed N issue(s).
Remaining: N manual issues across X files.
Remaining issues (if any): <describe what was left intentionally unfixed and why>
```

---

## Known patterns to watch for

These patterns account for the majority of historical issues in this repo:

1. **`my-flink/` at repo root** — old path; correct is `code/flink-java/my-flink/`  *(auto-fixed)*
2. **`flink-sql/` at repo root** — old path; correct is `code/flink-sql/`  *(auto-fixed)*
3. **`kafka-flink-demo/`** — deleted folder; was absorbed into `code/flink-java/`  *(manual)*
4. **`e2e-demos/*/k8s/`** — K8s manifest sub-paths not yet created  *(manual)*
5. **`code/flink-sql/08-snapshot-query`** — actual dir is `08-snapshot-external-query`  *(manual)*
6. **`flink-sql/01-confluent-kafka-local-flink`** (case `-Flink`) — actual dir is all-lowercase  *(auto-fixed)*

---

## Tool locations

| Tool | Location | Use when |
|------|----------|----------|
| Rich Typer CLI | `tools/doc_sync.py` | Normal use — rich output, `--fix`, `--agent` |
| Stdlib fallback | `.bob/skills/flink-doc-sync/doc_sync_audit.py` | No `uv`/venv available; CI/plain markdown output |

To add a new check to the CLI, add a `check_*()` function that returns `list[Issue]`
and call `_render_issues()` in the `audit` command.
