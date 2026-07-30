"""
Deploy manifest model, I/O, and template generation from Flink SQL folders.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field, model_validator

DEFAULT_MANIFEST = "deploy_manifest.json"
DEFAULT_USER_AGENT = "cc-sql-tools/0.1"

_CREATE_TABLE_RE = re.compile(
    r"create\s+table\s+(?:if\s+not\s+exists\s+)?([`\"]?[\w.]+[`\"]?)",
    re.IGNORECASE,
)


class StatementRef(BaseModel):
    name: str
    file: str


class DeployManifest(BaseModel):
    """Deploy manifest structure for Flink SQL statement groups."""

    user_agent: str = DEFAULT_USER_AGENT
    groups: dict[str, list[StatementRef]] = Field(default_factory=dict)
    deploy_all: list[str] = Field(default_factory=list)
    undeploy_all: list[str] = Field(default_factory=list)
    drop_tables: list[str] = Field(default_factory=list)
    drop_statement_prefix: str | None = None

    @model_validator(mode="before")
    @classmethod
    def _normalize_legacy_fields(cls, data: Any) -> Any:
        if not isinstance(data, dict):
            return data

        groups = data.get("groups") or {}
        drop_tables = data.get("drop_tables", [])
        if (
            isinstance(drop_tables, list)
            and drop_tables
            and isinstance(drop_tables[0], dict)
        ):
            data = {**data, "drop_tables": [entry["table"] for entry in drop_tables]}

        deploy_all = data.get("deploy_all")
        if not deploy_all:
            data = {**data, "deploy_all": list(groups.keys())}

        if not data.get("undeploy_all"):
            data = {**data, "undeploy_all": []}

        if not data.get("drop_statement_prefix"):
            ddl = groups.get("ddl") or []
            if ddl:
                first = ddl[0]
                first_name = first["name"] if isinstance(first, dict) else first.name
                if "-ddl-" in first_name:
                    data = {
                        **data,
                        "drop_statement_prefix": first_name.split("-ddl-")[0],
                    }

        if "user_agent" not in data or not data.get("user_agent"):
            data = {**data, "user_agent": DEFAULT_USER_AGENT}

        return data

    def statements_for(self, group: str) -> list[StatementRef]:
        if group == "all":
            out: list[StatementRef] = []
            for g in self.deploy_all:
                out.extend(self.groups.get(g, []))
            return out
        if group not in self.groups:
            raise KeyError(f"Unknown group {group!r}; available: {sorted(self.groups)}")
        return list(self.groups[group])

    def undeploy_order(self, group: str) -> list[StatementRef]:
        return list(reversed(self.statements_for(group)))

    def statements_for_full_undeploy(self) -> list[StatementRef]:
        """Statement delete order: stop streaming DML before one-shot inserts."""
        groups = self.undeploy_all or [
            g for g in self.groups if g != "ddl"
        ]
        ordered: list[StatementRef] = []
        for group in reversed(groups):
            ordered.extend(reversed(self.groups.get(group, [])))
        return ordered

    def drop_statement_name(self, table: str) -> str:
        prefix = self.drop_statement_prefix or "drop"
        safe_table = table.replace(".", "-")
        return f"{prefix}-{safe_table}"


def load_manifest(manifest_path: Path) -> DeployManifest:
    data: dict[str, Any] = json.loads(manifest_path.read_text(encoding="utf-8"))
    return DeployManifest.model_validate(data)


def write_manifest(manifest: DeployManifest, manifest_path: Path) -> Path:
    text = json.dumps(manifest.model_dump(exclude_none=True), indent=2) + "\n"
    manifest_path.write_text(text, encoding="utf-8")
    return manifest_path


def _slugify(value: str) -> str:
    """Convert folder or file stem to a manifest-safe slug."""
    slug = value.strip().lower().replace("_", "-")
    slug = re.sub(r"[^a-z0-9-]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or "demo"


def _classify_sql_file(filename: str) -> str:
    """Map a SQL filename to a manifest group."""
    name = filename.lower()
    if name.startswith("ddl."):
        return "ddl"
    if (
        name.startswith("insert_")
        or name.startswith("insert.")
        or name.startswith("dml.insert_")
        or name.startswith("dml.insert.")
    ):
        return "data"
    if name.startswith("dml.update_") or name.startswith("scenario."):
        return "scenario"
    if name.startswith("dml."):
        return "pipeline"
    if name.startswith("insert"):
        return "data"
    return "pipeline"


def _statement_name(prefix: str, group: str, rel_path: str) -> str:
    """Build a Flink statement name from prefix, group, and SQL path relative to sql-dir."""
    path = Path(rel_path)
    stem = path.stem
    for lead in (f"{group}.", "ddl.", "dml.", "scenario."):
        if stem.startswith(lead):
            stem = stem[len(lead) :]
            break
    slug = _slugify(stem.replace(".", "-"))
    if path.parent != Path("."):
        folder_slug = "-".join(_slugify(part) for part in path.parent.parts)
        return f"{prefix}-{folder_slug}-{group}-{slug}"
    return f"{prefix}-{group}-{slug}"


def _extract_table_name_from_ddl(path: Path) -> str | None:
    """Return the table name from a CREATE TABLE DDL file."""
    match = _CREATE_TABLE_RE.search(path.read_text(encoding="utf-8"))
    if not match:
        return None
    name = match.group(1).strip("`\"")
    return name.split(".")[-1]


_SKIP_DIR_NAMES = frozenset({".git", "__pycache__", "node_modules", ".venv"})


def _is_deployable_sql_path(sql_dir: Path, path: Path) -> bool:
    if not path.is_file() or path.suffix.lower() != ".sql":
        return False
    rel_parts = path.relative_to(sql_dir).parts
    parent_parts = rel_parts[:-1]
    if any(part.startswith(".") or part in _SKIP_DIR_NAMES for part in parent_parts):
        return False
    # Seed inserts under tests/ are deployable data; skip other test fixtures (e.g. ddl.*).
    if "tests" in parent_parts and _classify_sql_file(path.name) != "data":
        return False
    return True


def _discover_sql_files(sql_dir: Path) -> list[Path]:
    """List deployable SQL files under a demo folder (recursive)."""
    return sorted(
        path for path in sql_dir.rglob("*.sql") if _is_deployable_sql_path(sql_dir, path)
    )


def _default_deploy_all(groups: dict[str, list[StatementRef]]) -> list[str]:
    order = ["ddl", "pipeline", "data"]
    return [group for group in order if group in groups]


def _default_undeploy_all(groups: dict[str, list[StatementRef]]) -> list[str]:
    order = ["scenario", "data", "pipeline"]
    return [group for group in order if group in groups]


def _infer_drop_tables(ddl_files: list[Path]) -> list[str]:
    """Infer drop_tables order: dependents first (reverse ddl filename order)."""
    tables: list[str] = []
    for path in sorted(ddl_files):
        table = _extract_table_name_from_ddl(path)
        if table:
            tables.append(table)
    return list(reversed(tables))


def create_manifest_from_folder(
    sql_dir: Path,
    *,
    prefix: str | None = None,
    user_agent: str | None = None,
    manifest_name: str = DEFAULT_MANIFEST,
    write: bool = False,
    overwrite: bool = False,
) -> DeployManifest:
    """
    Build a deploy manifest template by scanning SQL files under a demo folder tree.

    Subdirectories are included recursively. Manifest ``file`` entries are paths
    relative to ``sql_dir`` (for example ``kes-chat/ddl.events.sql``).

    Files are grouped by naming convention:
    - ddl.*.sql -> ddl
    - insert_*.sql / insert.*.sql / dml.insert_*.sql / dml.insert.*.sql -> data
      (including under a tests/ subdirectory)
    - dml.update_*.sql / scenario.*.sql -> scenario
    - other dml.*.sql -> pipeline

    Files under ``tests/`` are included only when classified as ``data`` (seed inserts).
    Other test fixtures (for example ``tests/ddl.*.sql``) are skipped.

    Statement names follow ``{prefix}-{group}-{file-slug}`` for top-level files,
    or ``{prefix}-{folder-slug}-{group}-{file-slug}`` when nested.
    """
    sql_dir = sql_dir.resolve()
    if not sql_dir.is_dir():
        raise NotADirectoryError(f"sql-dir not found: {sql_dir}")

    manifest_path = sql_dir / manifest_name
    if write and manifest_path.exists() and not overwrite:
        raise FileExistsError(
            f"Manifest already exists: {manifest_path} (pass overwrite=True to replace)"
        )

    folder_slug = _slugify(sql_dir.name)
    prefix = _slugify(prefix or folder_slug)
    user_agent = user_agent or DEFAULT_USER_AGENT

    groups: dict[str, list[StatementRef]] = {}
    ddl_files: list[Path] = []

    for path in _discover_sql_files(sql_dir):
        rel = path.relative_to(sql_dir).as_posix()
        group = _classify_sql_file(path.name)
        if group == "ddl":
            ddl_files.append(path)
        entry = StatementRef(name=_statement_name(prefix, group, rel), file=rel)
        groups.setdefault(group, []).append(entry)

    deploy_all = _default_deploy_all(groups)
    undeploy_all = _default_undeploy_all(groups)
    drop_tables = _infer_drop_tables(ddl_files)

    manifest = DeployManifest(
        user_agent=user_agent,
        groups=groups,
        deploy_all=deploy_all,
        undeploy_all=undeploy_all,
        drop_tables=drop_tables,
        drop_statement_prefix=f"{prefix}-drop",
    )

    if write:
        write_manifest(manifest, manifest_path)

    return manifest
