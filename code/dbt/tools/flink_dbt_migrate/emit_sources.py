"""Emit and merge dbt sources.yaml entries from upstream Flink DDLs."""

from __future__ import annotations

from pathlib import Path

import yaml

from flink_dbt_migrate.discover_deps import UpstreamDep
from flink_dbt_migrate.parse_ddl import DdlTable
from flink_dbt_migrate.type_map import flink_type_to_dbt

SOURCES_YML_NAME = "sources.yaml"


def build_source_table_entry(
    table_name: str,
    ddl: DdlTable,
    *,
    identifier: str | None = None,
) -> dict:
    return {
        "name": table_name,
        "identifier": identifier or table_name,
        "columns": [
            {
                "name": column.name,
                "data_type": flink_type_to_dbt(column.flink_type),
            }
            for column in ddl.columns
        ],
    }


def load_sources_yml(path: Path) -> dict:
    if not path.exists():
        return {"version": 2, "sources": []}
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    data.setdefault("version", 2)
    data.setdefault("sources", [])
    return data


def source_entry_index(data: dict, source_name: str) -> int | None:
    for index, entry in enumerate(data["sources"]):
        if entry.get("name") == source_name:
            return index
    return None


def source_table_index(source_entry: dict, table_name: str) -> int | None:
    for index, entry in enumerate(source_entry.setdefault("tables", [])):
        if entry.get("name") == table_name:
            return index
    return None


def merge_sources_yml(
    data: dict,
    source_name: str,
    table_entries: list[dict],
    *,
    force: bool = False,
) -> dict:
    source_index = source_entry_index(data, source_name)
    if source_index is None:
        data["sources"].append({"name": source_name, "tables": []})
        source_index = len(data["sources"]) - 1

    source_entry = data["sources"][source_index]
    for table_entry in table_entries:
        table_name = table_entry["name"]
        index = source_table_index(source_entry, table_name)
        if index is None:
            source_entry["tables"].append(table_entry)
        elif force:
            source_entry["tables"][index] = table_entry
        else:
            existing = source_entry["tables"][index]
            existing.setdefault("identifier", table_entry.get("identifier"))
            existing_columns = {
                column["name"]: column
                for column in existing.setdefault("columns", [])
            }
            for column in table_entry.get("columns", []):
                if column["name"] not in existing_columns:
                    existing["columns"].append(column)
                elif "data_type" not in existing_columns[column["name"]]:
                    existing_columns[column["name"]]["data_type"] = column["data_type"]

    source_entry["tables"] = sorted(
        source_entry["tables"],
        key=lambda entry: entry["name"],
    )
    data["sources"] = sorted(data["sources"], key=lambda entry: entry["name"])
    return data


def dump_sources_yml(data: dict) -> str:
    return yaml.safe_dump(
        data,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )


def emit_sources_yml(
    project_models_dir: Path,
    source_name: str,
    upstream_deps: list[UpstreamDep],
    *,
    force: bool = False,
) -> str | None:
    source_deps = [
        dep for dep in upstream_deps if dep.resolution == "source" and dep.ddl is not None
    ]
    if not source_deps:
        return None

    table_entries = [
        build_source_table_entry(dep.table_name, dep.ddl)
        for dep in source_deps
        if dep.ddl is not None
    ]
    path = project_models_dir / SOURCES_YML_NAME
    data = load_sources_yml(path)
    merge_sources_yml(data, source_name, table_entries, force=force)
    return dump_sources_yml(data)
