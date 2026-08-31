#!/usr/bin/env python3
"""
flink-doc-sync audit script
Runs three checks against the flink-studies docs/ folder and prints
results as markdown tables to stdout.

Usage (from repo root):
    python .bob/skills/flink-doc-sync/doc_sync_audit.py
"""
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
DOCS_DIR = REPO_ROOT / "docs"
MKDOCS_YML = REPO_ROOT / "mkdocs.yml"
BLOB_PREFIX = "https://github.com/jbcodeforce/flink-studies/blob/master/"
TREE_PREFIX = "https://github.com/jbcodeforce/flink-studies/tree/master/"

# ── helpers ──────────────────────────────────────────────────────────────────

def all_doc_files():
    return sorted(DOCS_DIR.rglob("*.md"))


def repo_path_exists(rel: str) -> bool:
    """Return True if a repo-relative path (file or dir) exists."""
    # strip URL fragment
    rel = rel.split("#")[0].rstrip("/")
    return (REPO_ROOT / rel).exists()


# ── Check 1: GitHub blob/tree URL references ─────────────────────────────────

def check_github_urls():
    pattern = re.compile(
        r"https://github\.com/jbcodeforce/flink-studies/(?:blob|tree)/master/([^\s\)\"']+)"
    )
    rows = []
    for md in all_doc_files():
        rel_doc = md.relative_to(REPO_ROOT)
        for lineno, line in enumerate(md.read_text(errors="replace").splitlines(), 1):
            for m in pattern.finditer(line):
                raw_path = m.group(1).split("#")[0].rstrip("/")
                exists = (REPO_ROOT / raw_path).exists()
                if not exists:
                    rows.append((str(rel_doc), lineno, raw_path, "❌ MISSING"))
    return rows


# ── Check 2: mkdocs.yml nav file existence ───────────────────────────────────

def check_mkdocs_nav():
    nav_file_pattern = re.compile(r":\s+([\w/\-\.]+\.md)\s*$")
    rows = []
    if not MKDOCS_YML.exists():
        return [("mkdocs.yml", 0, "mkdocs.yml not found", "❌ MISSING")]
    for lineno, line in enumerate(MKDOCS_YML.read_text().splitlines(), 1):
        m = nav_file_pattern.search(line)
        if m:
            nav_path = m.group(1)
            # nav paths are relative to docs/
            target = DOCS_DIR / nav_path
            if not target.exists():
                rows.append(("mkdocs.yml", lineno, nav_path, "❌ MISSING"))
    return rows


# ── Check 3: inline version string consistency ───────────────────────────────

def canonical_versions():
    """Read canonical versions from deployment/docker/docker-compose.yaml and pyproject.toml."""
    versions = {}
    cp_compose = REPO_ROOT / "deployment" / "docker" / "docker-compose.yaml"
    if cp_compose.exists():
        m = re.search(r"confluentinc/cp-kafka:(\d+\.\d+\.\d+)", cp_compose.read_text())
        if m:
            versions["cp"] = m.group(1)
    py_proj = REPO_ROOT / "pyproject.toml"
    if py_proj.exists():
        m = re.search(r'apache-flink[=~><]+(\d+\.\d+\.\d+)', py_proj.read_text())
        if m:
            versions["flink_python"] = m.group(1)
    return versions


def check_version_strings():
    canonical = canonical_versions()
    rows = []

    # patterns: (label, regex, canonical_key)
    # Only match CP _broker/kafka_ images — not cp-flink which uses Flink versioning
    checks = [
        ("CP version", re.compile(r"confluentinc/cp-(?:kafka|schema-registry|control-center|kafka-rest|connect|ksqldb)[^:]*:(\d+\.\d+\.\d+)"), "cp"),
    ]

    for md in all_doc_files():
        rel_doc = str(md.relative_to(REPO_ROOT))
        text = md.read_text(errors="replace")
        for lineno, line in enumerate(text.splitlines(), 1):
            for label, pat, key in checks:
                for m in pat.finditer(line):
                    found = m.group(1)
                    canon = canonical.get(key)
                    if canon and found != canon:
                        rows.append((
                            rel_doc, lineno,
                            f"{label}: {found}",
                            f"⚠️  canonical is {canon}"
                        ))
    return rows


# ── Render ────────────────────────────────────────────────────────────────────

def render_table(title, headers, rows):
    print(f"\n### {title}")
    if not rows:
        print("✅ No issues found.\n")
        return
    col_w = [max(len(h), max((len(str(r[i])) for r in rows), default=0)) for i, h in enumerate(headers)]
    sep = "| " + " | ".join("-" * w for w in col_w) + " |"
    header_row = "| " + " | ".join(h.ljust(col_w[i]) for i, h in enumerate(headers)) + " |"
    print(header_row)
    print(sep)
    for row in rows:
        print("| " + " | ".join(str(row[i]).ljust(col_w[i]) for i in range(len(headers))) + " |")
    print(f"\n**{len(rows)} issue(s) found.**\n")


def main():
    print("# flink-doc-sync Audit Report\n")
    print(f"Repo root: `{REPO_ROOT}`\n")

    url_rows = check_github_urls()
    render_table(
        "Check 1 — GitHub URL references (blob/tree) pointing to missing paths",
        ["Doc file", "Line", "Referenced path", "Status"],
        url_rows
    )

    nav_rows = check_mkdocs_nav()
    render_table(
        "Check 2 — mkdocs.yml nav entries pointing to missing files",
        ["File", "Line", "Nav path", "Status"],
        nav_rows
    )

    ver_rows = check_version_strings()
    render_table(
        "Check 3 — Inline version strings inconsistent with canonical sources",
        ["Doc file", "Line", "Found", "Note"],
        ver_rows
    )

    total = len(url_rows) + len(nav_rows) + len(ver_rows)
    print(f"---\n**Total issues: {total}**")
    sys.exit(1 if total > 0 else 0)


if __name__ == "__main__":
    main()
