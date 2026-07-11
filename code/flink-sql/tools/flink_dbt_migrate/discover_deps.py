"""Discover upstream Flink table dependencies for dbt migration."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from flink_dbt_migrate.parse_ddl import DdlTable, parse_ddl
from flink_dbt_migrate.parse_dml import DmlStatement
from flink_dbt_migrate.rewrite_refs import collect_cte_names, strip_identifier

_TABLE_TAIL = r"(?=[\s,\)]|$|\s+AS\b)"
_NOT_SUBQUERY = r"(?!\s*\()"

_FROM_PATTERN = re.compile(
    rf"\bFROM\s+(`?[\w]+`?){_TABLE_TAIL}{_NOT_SUBQUERY}",
    re.IGNORECASE,
)
_JOIN_PATTERN = re.compile(
    rf"\b(?:JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|INNER\s+JOIN|"
    rf"FULL\s+JOIN|CROSS\s+JOIN)\s+(`?[\w]+`?){_TABLE_TAIL}{_NOT_SUBQUERY}",
    re.IGNORECASE,
)
_TABLE_PATTERN = re.compile(rf"\bTABLE\s+(`?[\w]+`?)\b", re.IGNORECASE)
_CREATE_TABLE_PATTERN = re.compile(
    r"\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(`?[\w]+`?)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class UpstreamDep:
    table_name: str
    ddl_path: Path | None
    ddl: DdlTable | None
    resolution: Literal["ref", "source"]
    ref_model: str | None = None
    source_name: str | None = None


def default_source_name(source_project_dir: Path) -> str:
    name = source_project_dir.name.replace("-", "_").replace(".", "_")
    name = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    return name.lower()


def collect_upstream_tables(body: str, cte_names: set[str]) -> list[str]:
    tables: list[str] = []
    seen: set[str] = set()

    for pattern in (_FROM_PATTERN, _JOIN_PATTERN, _TABLE_PATTERN):
        for match in pattern.finditer(body):
            table = strip_identifier(match.group(1))
            if table in cte_names or table in seen:
                continue
            seen.add(table)
            tables.append(table)

    return tables


def _ddl_suffix_candidates(table_name: str) -> list[str]:
    candidates = [table_name]
    if "_" in table_name:
        prefix, suffix = table_name.split("_", 1)
        if prefix.isdigit() or (prefix.startswith("d") and prefix[1:].isdigit()):
            candidates.append(suffix)
    return list(dict.fromkeys(candidates))


def discover_upstream_ddl(source_dir: Path, table_name: str) -> Path:
    source_dir = source_dir.resolve()

    for suffix in _ddl_suffix_candidates(table_name):
        candidate = source_dir / f"ddl.{suffix}.sql"
        if candidate.is_file():
            text = candidate.read_text(encoding="utf-8")
            for match in _CREATE_TABLE_PATTERN.finditer(text):
                if strip_identifier(match.group(1)) == table_name:
                    return candidate

    direct = source_dir / f"ddl.{table_name}.sql"
    if direct.is_file():
        return direct

    matches: list[Path] = []
    for ddl_path in sorted(source_dir.glob("ddl*.sql")):
        text = ddl_path.read_text(encoding="utf-8")
        for match in _CREATE_TABLE_PATTERN.finditer(text):
            if strip_identifier(match.group(1)) == table_name:
                matches.append(ddl_path)
                break

    if not matches:
        raise FileNotFoundError(
            f"No DDL file found for upstream table {table_name} in {source_dir}. "
            f"Tried ddl.{table_name}.sql and scanned ddl*.sql."
        )

    if len(matches) == 1:
        return matches[0]

    def rank(path: Path) -> tuple[int, int, str]:
        name = path.name.lower()
        wm_penalty = 1 if "_wm" in name else 0
        return (wm_penalty, len(name), name)

    return sorted(matches, key=rank)[0]


def find_dbt_model(project_dir: Path, model_name: str) -> Path | None:
    models_dir = project_dir / "models"
    if not models_dir.is_dir():
        return None

    matches = [
        path
        for path in models_dir.rglob("*.sql")
        if path.stem == model_name
    ]
    if not matches:
        return None
    if len(matches) > 1:
        return matches[0]
    return matches[0]


def resolve_upstream_deps(
    source_project_dir: Path,
    dbt_project_dir: Path | None,
    dml: DmlStatement,
    *,
    ref_overrides: dict[str, str] | None = None,
    source_name: str | None = None,
    resolve_sources: bool = True,
) -> list[UpstreamDep]:
    ref_overrides = ref_overrides or {}
    cte_names = collect_cte_names(dml.body)
    upstream_tables = collect_upstream_tables(dml.body, cte_names)
    resolved_source_name = source_name or default_source_name(source_project_dir)

    deps: list[UpstreamDep] = []
    for table_name in upstream_tables:
        if table_name in ref_overrides:
            deps.append(
                UpstreamDep(
                    table_name=table_name,
                    ddl_path=None,
                    ddl=None,
                    resolution="ref",
                    ref_model=ref_overrides[table_name],
                )
            )
            continue

        ref_model_path = (
            find_dbt_model(dbt_project_dir, table_name)
            if dbt_project_dir is not None
            else None
        )
        if ref_model_path is not None:
            deps.append(
                UpstreamDep(
                    table_name=table_name,
                    ddl_path=None,
                    ddl=None,
                    resolution="ref",
                    ref_model=table_name,
                )
            )
            continue

        if not resolve_sources:
            deps.append(
                UpstreamDep(
                    table_name=table_name,
                    ddl_path=None,
                    ddl=None,
                    resolution="ref",
                    ref_model=table_name,
                )
            )
            continue

        ddl_path = discover_upstream_ddl(source_project_dir, table_name)
        ddl = parse_ddl(ddl_path.read_text(encoding="utf-8"))
        deps.append(
            UpstreamDep(
                table_name=table_name,
                ddl_path=ddl_path,
                ddl=ddl,
                resolution="source",
                source_name=resolved_source_name,
            )
        )

    return deps
