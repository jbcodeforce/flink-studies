#!/usr/bin/env python3
"""
doc_sync — documentation audit and auto-fix tool for flink-studies.

Runs three deterministic checks against docs/ and reports every discrepancy.
Optionally auto-fixes common issues (--fix) or delegates ambiguous ones to an
Agno LLM agent (--agent).

Usage:
    uv run doc_sync.py audit                   # report only
    uv run doc_sync.py audit --fix             # report + auto-fix deterministic issues
    uv run doc_sync.py audit --agent           # report + LLM agent for ambiguous fixes
    uv run doc_sync.py audit --fix --agent     # both

    uv run doc_sync.py versions                # show canonical versions extracted from repo
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.table import Table
from rich import box
from rich.text import Text

# ── repo layout ──────────────────────────────────────────────────────────────

# tools/ lives one level below repo root
REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = REPO_ROOT / "docs"
MKDOCS_YML = REPO_ROOT / "mkdocs.yml"

app = typer.Typer(name="doc_sync", help=__doc__, no_args_is_help=True)
console = Console()

# ── data types ───────────────────────────────────────────────────────────────

class Issue:
    """One detected problem."""
    def __init__(self, check: str, doc_file: str, line: int, reference: str, note: str, fixable: bool = False):
        self.check = check
        self.doc_file = doc_file
        self.line = line
        self.reference = reference
        self.note = note
        self.fixable = fixable  # True = deterministic fix available
        self.fixed = False

# ── Check 1: GitHub blob/tree URL references ─────────────────────────────────

_GH_PATTERN = re.compile(
    r"https://github\.com/jbcodeforce/flink-studies/(?:blob|tree)/master/([^\s\)\"'#]+)"
)

# Known deterministic path corrections  {wrong_prefix: right_prefix}
_PATH_FIXES: list[tuple[re.Pattern, str]] = [
    # bare flink-sql/ or my-flink/ at root → code/flink-sql/ or code/flink-java/my-flink/
    (re.compile(r"^flink-sql/(.+)$"), r"code/flink-sql/\1"),
    (re.compile(r"^my-flink/(.+)$"), r"code/flink-java/my-flink/\1"),
    (re.compile(r"^flink-java/(.+)$"), r"code/flink-java/\1"),
    (re.compile(r"^flink-sql-demos/(.+)$"), r"code/flink-sql/\1"),
    # case-insensitive suffix mismatch (-Flink → -flink)
    (re.compile(r"^(code/flink-sql/\d+-[a-z-]+-)(F)(link.*)$"), r"\1f\3"),
]

def _try_fix_path(raw: str) -> str | None:
    """Return a corrected repo-relative path if a deterministic fix is known, else None."""
    for pattern, replacement in _PATH_FIXES:
        candidate = pattern.sub(replacement, raw)
        if candidate != raw and (REPO_ROOT / candidate).exists():
            return candidate
    return None


def check_github_urls() -> list[Issue]:
    issues: list[Issue] = []
    for md in sorted(DOCS_DIR.rglob("*.md")):
        rel_doc = str(md.relative_to(REPO_ROOT))
        for lineno, line in enumerate(md.read_text(errors="replace").splitlines(), 1):
            for m in _GH_PATTERN.finditer(line):
                raw_path = m.group(1).split("#")[0].rstrip("/")
                if (REPO_ROOT / raw_path).exists():
                    continue
                fix = _try_fix_path(raw_path)
                issues.append(Issue(
                    check="GitHub URL",
                    doc_file=rel_doc,
                    line=lineno,
                    reference=raw_path,
                    note=f"→ suggest: {fix}" if fix else "no auto-fix",
                    fixable=fix is not None,
                ))
    return issues


def fix_github_urls(issues: list[Issue]) -> int:
    """Apply deterministic URL fixes in-place. Returns count of fixes applied."""
    fixable = [i for i in issues if i.check == "GitHub URL" and i.fixable]
    if not fixable:
        return 0

    # Group by file
    by_file: dict[str, list[Issue]] = {}
    for issue in fixable:
        by_file.setdefault(issue.doc_file, []).append(issue)

    fixed = 0
    for rel_path, file_issues in by_file.items():
        target = REPO_ROOT / rel_path
        text = target.read_text(errors="replace")
        for issue in file_issues:
            corrected = _try_fix_path(issue.reference)
            if not corrected:
                continue
            old_url = f"https://github.com/jbcodeforce/flink-studies/blob/master/{issue.reference}"
            new_url_blob = f"https://github.com/jbcodeforce/flink-studies/blob/master/{corrected}"
            old_url_tree = f"https://github.com/jbcodeforce/flink-studies/tree/master/{issue.reference}"
            new_url_tree = f"https://github.com/jbcodeforce/flink-studies/tree/master/{corrected}"
            before = text
            text = text.replace(old_url, new_url_blob).replace(old_url_tree, new_url_tree)
            if text != before:
                issue.fixed = True
                fixed += 1
        target.write_text(text)
    return fixed


# ── Check 2: mkdocs.yml nav file existence ───────────────────────────────────

_NAV_MD = re.compile(r":\s+([\w/\-\.]+\.md)\s*$")


def check_mkdocs_nav() -> list[Issue]:
    issues: list[Issue] = []
    if not MKDOCS_YML.exists():
        return [Issue("mkdocs nav", "mkdocs.yml", 0, "mkdocs.yml", "file not found", fixable=False)]
    for lineno, line in enumerate(MKDOCS_YML.read_text().splitlines(), 1):
        m = _NAV_MD.search(line)
        if m:
            nav_path = m.group(1)
            if not (DOCS_DIR / nav_path).exists():
                issues.append(Issue(
                    check="mkdocs nav",
                    doc_file="mkdocs.yml",
                    line=lineno,
                    reference=nav_path,
                    note="nav entry missing from docs/",
                    fixable=False,
                ))
    return issues


# ── Check 3: inline CP version strings ───────────────────────────────────────

_CP_BROKER_IMAGE = re.compile(
    r"confluentinc/cp-(?:kafka|schema-registry|control-center|kafka-rest|connect|ksqldb)[^:]*:(\d+\.\d+\.\d+)"
)


def _canonical_cp_version() -> str | None:
    cp_compose = REPO_ROOT / "deployment" / "docker" / "docker-compose.yaml"
    if cp_compose.exists():
        m = re.search(r"confluentinc/cp-kafka:(\d+\.\d+\.\d+)", cp_compose.read_text())
        if m:
            return m.group(1)
    return None


def check_version_strings() -> list[Issue]:
    canon = _canonical_cp_version()
    issues: list[Issue] = []
    if not canon:
        return issues
    for md in sorted(DOCS_DIR.rglob("*.md")):
        rel_doc = str(md.relative_to(REPO_ROOT))
        for lineno, line in enumerate(md.read_text(errors="replace").splitlines(), 1):
            for m in _CP_BROKER_IMAGE.finditer(line):
                found = m.group(1)
                if found != canon:
                    issues.append(Issue(
                        check="version",
                        doc_file=rel_doc,
                        line=lineno,
                        reference=f"cp-*:{found}",
                        note=f"canonical is {canon}",
                        fixable=True,
                    ))
    return issues


def fix_version_strings(issues: list[Issue]) -> int:
    canon = _canonical_cp_version()
    if not canon:
        return 0
    fixable = [i for i in issues if i.check == "version" and i.fixable]
    by_file: dict[str, list[Issue]] = {}
    for issue in fixable:
        by_file.setdefault(issue.doc_file, []).append(issue)
    fixed = 0
    for rel_path, file_issues in by_file.items():
        target = REPO_ROOT / rel_path
        text = target.read_text(errors="replace")
        for issue in file_issues:
            old_ver = re.search(r":(\d+\.\d+\.\d+)", issue.reference).group(1)  # type: ignore[union-attr]
            before = text
            text = _CP_BROKER_IMAGE.sub(
                lambda mo: mo.group(0).replace(mo.group(1), canon),
                text,
            )
            if text != before:
                issue.fixed = True
                fixed += 1
        target.write_text(text)
    return fixed


# ── Rendering ─────────────────────────────────────────────────────────────────

def _render_issues(title: str, issues: list[Issue], show_fixable: bool = True) -> None:
    if not issues:
        console.print(f"  [green]✓ {title}[/green] — no issues\n")
        return

    tbl = Table(
        title=title,
        box=box.SIMPLE_HEAD,
        show_lines=False,
        header_style="bold cyan",
        title_style="bold",
    )
    tbl.add_column("File", style="dim", no_wrap=False)
    tbl.add_column("Line", justify="right", style="dim", no_wrap=True)
    tbl.add_column("Reference", no_wrap=False)
    tbl.add_column("Note", no_wrap=False)
    if show_fixable:
        tbl.add_column("Fix?", justify="center", no_wrap=True)

    for issue in issues:
        status_cell = (
            Text("✔ fixed", style="green") if issue.fixed
            else (Text("⚡ auto", style="yellow") if issue.fixable else Text("✗ manual", style="red"))
        )
        row = [
            issue.doc_file,
            str(issue.line),
            issue.reference,
            issue.note,
        ]
        if show_fixable:
            row.append(status_cell)  # type: ignore[arg-type]
        tbl.add_row(*row)

    console.print(tbl)
    console.print()


# ── Agno agent for ambiguous issues ──────────────────────────────────────────

def _run_agent(issues: list[Issue], model_id: str, base_url: str) -> None:
    """Use an Agno agent to suggest or apply fixes for issues that are not auto-fixable."""
    unfixable = [i for i in issues if not i.fixable and not i.fixed]
    if not unfixable:
        console.print("[green]No ambiguous issues for agent to handle.[/green]")
        return

    try:
        from agno.agent import Agent
        from agno.models.openai.like import OpenAILike
    except ImportError:
        console.print("[red]agno is not installed. Run: uv add agno[/red]")
        raise typer.Exit(1)

    summary_lines = [
        f"- [{i.check}] {i.doc_file}:{i.line} — `{i.reference}` ({i.note})"
        for i in unfixable
    ]
    prompt = (
        "You are a documentation maintainer for the flink-studies repository "
        "(https://github.com/jbcodeforce/flink-studies).\n\n"
        "The following documentation references are broken — the files they point to "
        "do not exist in the repo. For each one, suggest what the correct path should "
        "be, or whether the link should simply be removed. Be concise.\n\n"
        "Issues:\n" + "\n".join(summary_lines)
    )

    agent = Agent(
        name="doc-sync-agent",
        model=OpenAILike(id=model_id, base_url=base_url, api_key="localkey"),
        markdown=True,
    )

    console.rule("[bold yellow]Agent suggestions for ambiguous issues[/bold yellow]")
    console.print(f"[dim]Model: {model_id} @ {base_url}[/dim]\n")
    response = agent.run(prompt)
    if response.content:
        console.print(response.content)


# ── Commands ──────────────────────────────────────────────────────────────────

@app.command()
def audit(
    fix: Annotated[bool, typer.Option("--fix", help="Auto-apply deterministic fixes.")] = False,
    agent: Annotated[bool, typer.Option("--agent", help="Use Agno LLM for ambiguous issues.")] = False,
    model: Annotated[str, typer.Option("--model", help="LLM model id (Agno).")] = "hermes3:latest",
    base_url: Annotated[str, typer.Option("--base-url", help="OpenAI-compatible base URL.")] = "http://127.0.0.1:11434/v1",
    fail_on_issues: Annotated[bool, typer.Option("--fail/--no-fail", help="Exit 1 if issues remain after fixes.")] = True,
) -> None:
    """Audit docs/ for broken references, stale nav entries, and version drift."""
    console.rule("[bold]flink-doc-sync audit[/bold]")
    console.print(f"[dim]Repo root: {REPO_ROOT}[/dim]\n")

    # ── run checks ──
    url_issues   = check_github_urls()
    nav_issues   = check_mkdocs_nav()
    ver_issues   = check_version_strings()
    all_issues   = url_issues + nav_issues + ver_issues

    # ── apply deterministic fixes ──
    total_fixed = 0
    if fix:
        total_fixed += fix_github_urls(url_issues)
        total_fixed += fix_version_strings(ver_issues)
        if total_fixed:
            console.print(f"[green]Auto-fixed {total_fixed} issue(s).[/green]\n")

    # ── render results ──
    _render_issues("Check 1 — GitHub URL references", url_issues)
    _render_issues("Check 2 — mkdocs.yml nav entries", nav_issues)
    _render_issues("Check 3 — Inline CP version strings", ver_issues)

    # ── summary ──
    remaining = sum(1 for i in all_issues if not i.fixed)
    fixable_remaining = sum(1 for i in all_issues if not i.fixed and i.fixable)
    manual_remaining = sum(1 for i in all_issues if not i.fixed and not i.fixable)
    console.rule()
    console.print(
        f"[bold]Total:[/bold] {len(all_issues)} issue(s) found  |  "
        f"[green]{total_fixed} fixed[/green]  |  "
        f"[yellow]{fixable_remaining} auto-fixable remaining[/yellow]  |  "
        f"[red]{manual_remaining} need manual review[/red]"
    )
    if fixable_remaining and not fix:
        console.print("[dim]Tip: run with --fix to apply deterministic fixes.[/dim]")

    # ── optional agent ──
    if agent:
        console.print()
        _run_agent(all_issues, model_id=model, base_url=base_url)

    if fail_on_issues and remaining > 0:
        raise typer.Exit(1)


@app.command()
def versions() -> None:
    """Show the canonical versions extracted from the repo."""
    cp = _canonical_cp_version()
    console.print("[bold]Canonical versions[/bold]")
    console.print(f"  CP broker:  {cp or '[dim]not found[/dim]'}")

    py_proj = REPO_ROOT / "pyproject.toml"
    flink_py = None
    if py_proj.exists():
        m = re.search(r'apache-flink[=~><]+(\d+\.\d+\.\d+)', py_proj.read_text())
        if m:
            flink_py = m.group(1)
    console.print(f"  Flink (py): {flink_py or '[dim]not found[/dim]'}")

    k8s_mk = REPO_ROOT / "deployment" / "k8s" / "Makefile"
    if k8s_mk.exists():
        mk_text = k8s_mk.read_text()
        for var in ("FLINK_OPERATOR_VERSION", "CERT_MGR_VERSION"):
            m2 = re.search(rf"{var}\s*=\s*(\S+)", mk_text)
            if m2:
                console.print(f"  {var}: {m2.group(1)}")


if __name__ == "__main__":
    app()
