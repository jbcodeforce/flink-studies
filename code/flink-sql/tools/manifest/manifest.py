"""
Deploy manifest model, I/O, and template generation from Flink SQL folders.

Also supports dbt-confluent projects via :func:`create_manifest_from_dbt_folder`.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import yaml
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


# ---------------------------------------------------------------------------
# dbt-confluent project support
# ---------------------------------------------------------------------------

#: Deploy/undeploy group ordering for dbt projects (sources-first deploy,
#: dependents-first undeploy).
_DBT_DEPLOY_ORDER = ["seeds", "sources", "dimensions", "pipeline", "facts", "marts"]
_DBT_UNDEPLOY_ORDER = list(reversed(_DBT_DEPLOY_ORDER))

#: Map from the deepest path segment that matches a layer name to the manifest group.
_DBT_LAYER_TO_GROUP: dict[str, str] = {
    "sources": "sources",
    "dimensions": "dimensions",
    "facts": "facts",
    "marts": "marts",
}


def _find_dbt_project_root(start: Path) -> Path:
    """Locate the dbt project root from *start*.

    Search order:
    1. *start* itself contains ``dbt_project.yml``.
    2. Walk up parents looking for ``sl_dbt.yaml`` (the shift-left marker that
       sits alongside ``dbt_project.yml``).

    Raises :class:`FileNotFoundError` if neither is found.
    """
    start = start.resolve()
    candidate = start if start.is_dir() else start.parent
    for directory in [candidate, *candidate.parents]:
        if (directory / "dbt_project.yml").exists():
            return directory
        if (directory / "sl_dbt.yaml").exists():
            return directory
    raise FileNotFoundError(
        f"Could not find a dbt project root (no dbt_project.yml or sl_dbt.yaml) "
        f"starting from {start}"
    )


def _read_dbt_project_name(project_root: Path) -> str:
    """Return the ``name`` field from *project_root*/dbt_project.yml."""
    yml_path = project_root / "dbt_project.yml"
    try:
        data = yaml.safe_load(yml_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ValueError(f"Cannot parse {yml_path}: {exc}") from exc
    name = (data or {}).get("name")
    if not name:
        raise ValueError(f"'name' field missing in {yml_path}")
    return str(name)


def _read_dbt_profile_name(project_root: Path) -> str:
    """Return the ``profile`` field from dbt_project.yml, defaulting to 'default'."""
    yml_path = project_root / "dbt_project.yml"
    try:
        data = yaml.safe_load(yml_path.read_text(encoding="utf-8"))
    except Exception:
        return "default"
    return str((data or {}).get("profile", "default"))


def _read_statement_name_prefix(profile_name: str) -> str:
    """Return ``statement_name_prefix`` for *profile_name* from ``~/.dbt/profiles.yml``.

    Falls back to ``"dbt-"`` if the file is missing, the profile is not found,
    or the key is absent.
    """
    profiles_path = Path.home() / ".dbt" / "profiles.yml"
    try:
        data = yaml.safe_load(profiles_path.read_text(encoding="utf-8")) or {}
    except Exception:
        return "dbt-"
    profile = data.get(profile_name)
    if not isinstance(profile, dict):
        return "dbt-"
    # Check all output targets for the key.
    outputs = profile.get("outputs") or {}
    for output_cfg in outputs.values():
        if isinstance(output_cfg, dict) and "statement_name_prefix" in output_cfg:
            return str(output_cfg["statement_name_prefix"])
    return "dbt-"


def _dbt_group_for_node(path: str, resource_type: str) -> str:
    """Map a dbt node to a manifest group.

    *path* is the node's ``path`` field (relative to the models directory),
    e.g. ``user_reviews/sources/src_hosts.sql``.  We scan the *parent*
    directory segments from right to left (skipping the filename) and return
    the first layer name that matches.
    Seeds use a fixed group regardless of path.
    """
    if resource_type == "seed":
        return "seeds"
    # Use parent parts only — the filename itself is not a layer name.
    parent_parts = Path(path).parent.parts
    for part in reversed(parent_parts):
        segment = part.lower()
        if segment in _DBT_LAYER_TO_GROUP:
            return _DBT_LAYER_TO_GROUP[segment]
    return "pipeline"


def _read_dbt_manifest_nodes(project_root: Path) -> list[dict[str, Any]]:
    """Read ``target/manifest.json`` and return a normalised node list.

    Each entry is a dict with keys:
    ``name``, ``path``, ``resource_type``, ``statement_name_override`` (str | None).

    Raises :class:`FileNotFoundError` with a helpful message when the artifact is
    missing (user needs to run ``dbt run`` or ``dbt compile`` first).
    """
    manifest_path = project_root / "target" / "manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(
            f"dbt manifest not found: {manifest_path}\n"
            "Run 'dbt run' or 'dbt compile' inside the dbt project first."
        )
    raw: dict[str, Any] = json.loads(manifest_path.read_text(encoding="utf-8"))
    nodes: list[dict[str, Any]] = []
    for node_data in (raw.get("nodes") or {}).values():
        resource_type = node_data.get("resource_type", "")
        if resource_type not in ("model", "seed"):
            continue
        config = node_data.get("config") or {}
        statement_name_override: str | None = config.get("statement_name") or None
        nodes.append(
            {
                "name": node_data["name"],
                "path": node_data.get("path", ""),
                "resource_type": resource_type,
                "statement_name_override": statement_name_override,
            }
        )
    return nodes


def _read_dbt_source_tables(project_root: Path) -> list[str]:
    """Return raw source table names from ``models/**/sources.yaml`` files.

    These are Kafka/Flink tables that dbt references via ``{{ source(...) }}`` but
    does not own; they must still be dropped during a full teardown.
    Returns a deduplicated list in stable (discovery) order.
    """
    seen: dict[str, None] = {}
    for pattern in ("models/**/sources.yaml", "models/**/sources.yml"):
        for sources_file in sorted(project_root.glob(pattern)):
            try:
                data = yaml.safe_load(sources_file.read_text(encoding="utf-8")) or {}
            except Exception:
                continue
            for source in data.get("sources") or []:
                for table in source.get("tables") or []:
                    table_name = table.get("name")
                    if table_name:
                        seen[table_name] = None
    return list(seen.keys())


def create_manifest_from_dbt_folder(
    project_root: Path,
    *,
    user_agent: str | None = None,
    manifest_name: str = DEFAULT_MANIFEST,
    write: bool = False,
    overwrite: bool = False,
) -> DeployManifest:
    """Build a deploy manifest from a dbt-confluent project folder.

    Reads ``target/manifest.json`` (dbt's build artifact) to discover model and
    seed nodes, reconstructs the Flink statement names using the same
    ``sanitize_statement_name`` algorithm as dbt-confluent, and groups nodes by
    their dbt layer folder (``sources``, ``dimensions``, ``facts``, ``marts``).

    The ``file`` field of every :class:`StatementRef` is set to ``"_noop"``
    because dbt owns deployment; the manifest is used only for undeploy / drop.

    ``drop_tables`` includes (in teardown order):
    1. dbt model/seed tables (dependents first, sources/seeds last)
    2. raw source tables from ``models/**/sources.yaml``

    Requires ``dbt-confluent`` to be installed (``uv sync --extra dbt``).
    """
    try:
        from dbt.adapters.confluent.naming import sanitize_statement_name as _sanitize
    except ImportError as exc:
        raise ImportError(
            "dbt-confluent is required for --dbt mode. "
            "Install with: uv sync --extra dbt"
        ) from exc

    project_root = project_root.resolve()
    if not project_root.is_dir():
        raise NotADirectoryError(f"dbt project root not found: {project_root}")

    manifest_path = project_root / manifest_name
    if write and manifest_path.exists() and not overwrite:
        raise FileExistsError(
            f"Manifest already exists: {manifest_path} (pass overwrite=True to replace)"
        )

    project_name = _read_dbt_project_name(project_root)
    profile_name = _read_dbt_profile_name(project_root)
    prefix = _read_statement_name_prefix(profile_name)
    user_agent = user_agent or DEFAULT_USER_AGENT

    nodes = _read_dbt_manifest_nodes(project_root)

    groups: dict[str, list[StatementRef]] = {}
    for node in nodes:
        group = _dbt_group_for_node(node["path"], node["resource_type"])
        override: str | None = node["statement_name_override"]
        if override:
            raw_name = override
        else:
            raw_name = f"{prefix}{project_name}-{node['name']}"
        statement_name = _sanitize(raw_name)
        groups.setdefault(group, []).append(
            StatementRef(name=statement_name, file="_noop")
        )

    deploy_all = [g for g in _DBT_DEPLOY_ORDER if g in groups]
    undeploy_all = [g for g in _DBT_UNDEPLOY_ORDER if g in groups]

    # drop_tables: model/seed tables in undeploy order (dependents first), then raw sources.
    group_to_model_names: dict[str, list[str]] = {}
    for node in nodes:
        grp = _dbt_group_for_node(node["path"], node["resource_type"])
        group_to_model_names.setdefault(grp, []).append(node["name"])

    drop_tables: list[str] = []
    for grp in undeploy_all:
        drop_tables.extend(group_to_model_names.get(grp, []))

    # Append raw source tables (leaf inputs, dropped last)
    raw_sources = _read_dbt_source_tables(project_root)
    for src in raw_sources:
        if src not in drop_tables:
            drop_tables.append(src)

    drop_statement_prefix = _sanitize(f"{prefix}{project_name}-drop")

    manifest = DeployManifest(
        user_agent=user_agent,
        groups=groups,
        deploy_all=deploy_all,
        undeploy_all=undeploy_all,
        drop_tables=drop_tables,
        drop_statement_prefix=drop_statement_prefix,
    )

    if write:
        write_manifest(manifest, manifest_path)

    return manifest
