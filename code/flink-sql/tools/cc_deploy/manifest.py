"""
Deploy manifest model, I/O, and template generation from SQL demo folders.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULT_MANIFEST = "deploy_manifest.json"
DEFAULT_USER_AGENT = "flink-studies-sql-tools/0.1"

StatementRef = tuple[str, str]

_CREATE_TABLE_RE = re.compile(
    r"create\s+table\s+(?:if\s+not\s+exists\s+)?([`\"]?[\w.]+[`\"]?)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class DeployManifest:
    user_agent: str
    groups: dict[str, list[StatementRef]]
    deploy_all: list[str]
    undeploy_all: list[str]
    drop_tables: list[str]
    drop_statement_prefix: str | None = None

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
    return manifest_from_dict(data)


def manifest_from_dict(data: dict[str, Any]) -> DeployManifest:
    groups: dict[str, list[StatementRef]] = {}
    for group_name, entries in data.get("groups", {}).items():
        groups[group_name] = [(e["name"], e["file"]) for e in entries]

    deploy_all = data.get("deploy_all")
    if not deploy_all:
        deploy_all = list(groups.keys())

    undeploy_all = data.get("undeploy_all")
    drop_tables = data.get("drop_tables", [])
    if isinstance(drop_tables, list) and drop_tables and isinstance(drop_tables[0], dict):
        drop_tables = [entry["table"] for entry in drop_tables]

    drop_prefix = data.get("drop_statement_prefix")
    if not drop_prefix and groups.get("ddl"):
        first_name = groups["ddl"][0][0]
        if "-ddl-" in first_name:
            drop_prefix = first_name.split("-ddl-")[0]

    return DeployManifest(
        user_agent=data.get("user_agent", DEFAULT_USER_AGENT),
        groups=groups,
        deploy_all=deploy_all,
        undeploy_all=undeploy_all or [],
        drop_tables=drop_tables,
        drop_statement_prefix=drop_prefix,
    )


def manifest_to_dict(manifest: DeployManifest) -> dict[str, Any]:
    groups: dict[str, list[dict[str, str]]] = {}
    for group_name, entries in manifest.groups.items():
        groups[group_name] = [{"name": name, "file": rel} for name, rel in entries]

    data: dict[str, Any] = {
        "user_agent": manifest.user_agent,
        "deploy_all": manifest.deploy_all,
        "undeploy_all": manifest.undeploy_all,
        "drop_tables": manifest.drop_tables,
        "groups": groups,
    }
    if manifest.drop_statement_prefix:
        data["drop_statement_prefix"] = manifest.drop_statement_prefix
    return data


def write_manifest(manifest: DeployManifest, manifest_path: Path) -> Path:
    payload = manifest_to_dict(manifest)
    text = json.dumps(payload, indent=2) + "\n"
    manifest_path.write_text(text, encoding="utf-8")
    return manifest_path


def slugify(value: str) -> str:
    """Convert folder or file stem to a manifest-safe slug."""
    slug = value.strip().lower().replace("_", "-")
    slug = re.sub(r"[^a-z0-9-]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or "demo"


def classify_sql_file(filename: str) -> str:
    """Map a SQL filename to a manifest group."""
    name = filename.lower()
    if name.startswith("ddl."):
        return "ddl"
    if name.startswith("insert_") or name.startswith("dml.insert_"):
        return "data"
    if name.startswith("dml.update_") or name.startswith("scenario."):
        return "scenario"
    if name.startswith("dml."):
        return "pipeline"
    if name.startswith("insert"):
        return "data"
    return "pipeline"


def statement_name(prefix: str, group: str, filename: str) -> str:
    """Build a Flink statement name from prefix, group, and SQL filename."""
    stem = Path(filename).stem
    for lead in (f"{group}.", "ddl.", "dml.", "scenario."):
        if stem.startswith(lead):
            stem = stem[len(lead) :]
            break
    slug = slugify(stem.replace(".", "-"))
    return f"{prefix}-{group}-{slug}"


def extract_table_name_from_ddl(path: Path) -> str | None:
    """Return the table name from a CREATE TABLE DDL file."""
    match = _CREATE_TABLE_RE.search(path.read_text(encoding="utf-8"))
    if not match:
        return None
    name = match.group(1).strip("`\"")
    return name.split(".")[-1]


def discover_sql_files(sql_dir: Path) -> list[Path]:
    """List deployable SQL files in a demo folder (non-recursive)."""
    files = sorted(
        path
        for path in sql_dir.iterdir()
        if path.is_file()
        and path.suffix.lower() == ".sql"
        and path.name != DEFAULT_MANIFEST
    )
    return files


def default_deploy_all(groups: dict[str, list[StatementRef]]) -> list[str]:
    order = ["ddl", "pipeline", "data"]
    return [group for group in order if group in groups]


def default_undeploy_all(groups: dict[str, list[StatementRef]]) -> list[str]:
    order = ["scenario", "data", "pipeline"]
    return [group for group in order if group in groups]


def infer_drop_tables(ddl_files: list[Path]) -> list[str]:
    """Infer drop_tables order: dependents first (reverse ddl filename order)."""
    tables: list[str] = []
    for path in sorted(ddl_files):
        table = extract_table_name_from_ddl(path)
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
    Build a deploy manifest template by scanning SQL files in a demo folder.

    Files are grouped by naming convention:
    - ddl.*.sql -> ddl
    - insert_*.sql / dml.insert_*.sql -> data
    - dml.update_*.sql / scenario.*.sql -> scenario
    - other dml.*.sql -> pipeline

    Statement names follow ``{prefix}-{group}-{file-slug}``.
    """
    sql_dir = sql_dir.resolve()
    if not sql_dir.is_dir():
        raise NotADirectoryError(f"sql-dir not found: {sql_dir}")

    manifest_path = sql_dir / manifest_name
    if manifest_path.exists() and not overwrite:
        raise FileExistsError(
            f"Manifest already exists: {manifest_path} (pass overwrite=True to replace)"
        )

    folder_slug = slugify(sql_dir.name)
    prefix = slugify(prefix or folder_slug)
    user_agent = user_agent or f"flink-studies-{folder_slug}/0.1"

    groups: dict[str, list[StatementRef]] = {}
    ddl_files: list[Path] = []

    for path in discover_sql_files(sql_dir):
        group = classify_sql_file(path.name)
        if group == "ddl":
            ddl_files.append(path)
        entry = (statement_name(prefix, group, path.name), path.name)
        groups.setdefault(group, []).append(entry)

    deploy_all = default_deploy_all(groups)
    undeploy_all = default_undeploy_all(groups)
    drop_tables = infer_drop_tables(ddl_files)

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
