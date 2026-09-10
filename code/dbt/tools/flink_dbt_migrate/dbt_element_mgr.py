"""Emit and manage dbt elements: model SQL, schema.yml, seed CSV, and sources.yaml."""

from __future__ import annotations

import csv
import io
from pathlib import Path

import yaml

from flink_dbt_migrate.discover_deps import UpstreamDep
from flink_dbt_migrate.flink_sql_processor import DdlTable, DmlStatement, collect_cte_names
from flink_dbt_migrate.rewrite_refs import rewrite_refs
from flink_dbt_migrate.type_map import flink_type_to_dbt

# ---------------------------------------------------------------------------
# File name constants
# ---------------------------------------------------------------------------

SCHEMA_YML_NAME = "schema.yml"
SEED_SCHEMA_YML_NAME = "schema.yml"
SOURCES_YML_NAME = "sources.yaml"

# ---------------------------------------------------------------------------
# Model SQL (emit_model)
# ---------------------------------------------------------------------------


def format_config_block(
    ddl: DdlTable,
    materialized: str = "streaming_table",
) -> str:
    config_items: list[str] = [f"    materialized='{materialized}'"]

    if ddl.distributed_by:
        config_items.append(f"    distributed_by='{ddl.distributed_by}'")

    if ddl.with_options:
        with_lines = ["    with={"]
        items = list(ddl.with_options.items())
        for index, (key, value) in enumerate(items):
            comma = "," if index < len(items) - 1 else ""
            with_lines.append(f"        '{key}': '{value}'{comma}")
        with_lines.append("    }")
        config_items.append("\n".join(with_lines))

    inner = ",\n".join(config_items)
    return "{{ config(\n" + inner + "\n) }}"


def _resolution_maps(
    upstream_deps: list[UpstreamDep] | None,
) -> tuple[set[str], dict[str, str]]:
    ref_tables: set[str] = set()
    source_tables: dict[str, str] = {}
    if not upstream_deps:
        return ref_tables, source_tables

    for dep in upstream_deps:
        if dep.resolution == "ref" and dep.ref_model:
            ref_tables.add(dep.table_name)
        elif dep.resolution == "source" and dep.source_name:
            source_tables[dep.table_name] = dep.source_name
    return ref_tables, source_tables


def emit_model_sql(
    dml: DmlStatement,
    ddl: DdlTable,
    *,
    materialized: str = "streaming_table",
    ref_overrides: dict[str, str] | None = None,
    upstream_deps: list[UpstreamDep] | None = None,
    source_filename: str | None = None,
) -> str:
    cte_names = collect_cte_names(dml.body)
    ref_tables, source_tables = _resolution_maps(upstream_deps)
    body = rewrite_refs(
        dml.body,
        cte_names,
        ref_overrides,
        ref_tables=ref_tables,
        source_tables=source_tables,
    )

    parts: list[str] = [format_config_block(ddl, materialized=materialized), ""]

    migration_note = source_filename or dml.source_file
    if migration_note:
        parts.append(f"-- Migrated from {migration_note}")

    if dml.leading_comments:
        parts.append(dml.leading_comments)

    parts.append(body)
    return "\n".join(parts) + "\n"


# ---------------------------------------------------------------------------
# Model schema.yml (emit_schema)
# ---------------------------------------------------------------------------


def build_model_schema_entry(
    model_name: str,
    ddl: DdlTable,
    *,
    source_filename: str | None = None,
) -> dict:
    description = (
        f"Migrated from {source_filename}"
        if source_filename
        else f"Migrated Flink model for {ddl.table_name}"
    )
    return {
        "name": model_name,
        "description": description,
        "columns": [
            {
                "name": column.name,
                "data_type": flink_type_to_dbt(column.flink_type),
            }
            for column in ddl.columns
        ],
    }


def load_schema_yml(path: Path) -> dict:
    if not path.exists():
        return {"version": 2, "models": []}
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    data.setdefault("version", 2)
    data.setdefault("models", [])
    return data


def model_entry_index(data: dict, model_name: str) -> int | None:
    for index, entry in enumerate(data["models"]):
        if entry.get("name") == model_name:
            return index
    return None


def merge_model_schema(
    data: dict,
    model_entry: dict,
    *,
    force: bool = False,
) -> dict:
    model_name = model_entry["name"]
    index = model_entry_index(data, model_name)

    if index is None:
        data["models"].append(model_entry)
    elif force:
        data["models"][index] = model_entry
    else:
        existing = data["models"][index]
        existing.setdefault("description", model_entry.get("description"))
        existing_columns = {
            column["name"]: column for column in existing.setdefault("columns", [])
        }
        for column in model_entry["columns"]:
            if column["name"] not in existing_columns:
                existing["columns"].append(column)
            elif "data_type" not in existing_columns[column["name"]]:
                existing_columns[column["name"]]["data_type"] = column["data_type"]

    data["models"] = sorted(data["models"], key=lambda entry: entry["name"])
    return data


def dump_schema_yml(data: dict) -> str:
    return yaml.safe_dump(
        data,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )


def emit_schema_yml(
    target_dir: Path,
    model_name: str,
    ddl: DdlTable,
    *,
    source_filename: str | None = None,
    force: bool = False,
) -> str:
    data = load_schema_yml(target_dir / SCHEMA_YML_NAME)
    model_entry = build_model_schema_entry(
        model_name,
        ddl,
        source_filename=source_filename,
    )
    merge_model_schema(data, model_entry, force=force)
    return dump_schema_yml(data)


# ---------------------------------------------------------------------------
# Seed CSV + schema.yml (emit_seed)
# ---------------------------------------------------------------------------


def emit_seed_csv(columns: list[str], rows: list[list[str | None]]) -> str:
    """Render column headers and row data as standard CSV text."""
    buffer = io.StringIO()
    writer = csv.writer(buffer, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    writer.writerow(columns)
    for row in rows:
        writer.writerow(["" if cell is None else cell for cell in row])
    return buffer.getvalue()


def build_seed_schema_entry(
    seed_name: str,
    ddl: DdlTable,
    *,
    source_filename: str | None = None,
) -> dict:
    description = (
        f"Migrated from {source_filename}"
        if source_filename
        else f"Migrated Flink seed for {ddl.table_name}"
    )
    entry: dict = {
        "name": seed_name,
        "description": description,
        "config": {
            "column_types": {
                column.name: flink_type_to_dbt(column.flink_type)
                for column in ddl.columns
            },
        },
    }
    if ddl.with_options:
        entry["meta"] = {"flink_ddl_with_options": dict(ddl.with_options)}
    return entry


def load_seed_schema_yml(path: Path) -> dict:
    if not path.exists():
        return {"version": 2, "seeds": []}
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    data.setdefault("version", 2)
    data.setdefault("seeds", [])
    return data


def seed_entry_index(data: dict, seed_name: str) -> int | None:
    for index, entry in enumerate(data["seeds"]):
        if entry.get("name") == seed_name:
            return index
    return None


def merge_seed_schema(
    data: dict,
    seed_entry: dict,
    *,
    force: bool = False,
) -> dict:
    seed_name = seed_entry["name"]
    index = seed_entry_index(data, seed_name)

    if index is None:
        data["seeds"].append(seed_entry)
    elif force:
        data["seeds"][index] = seed_entry
    else:
        existing = data["seeds"][index]
        existing.setdefault("description", seed_entry.get("description"))
        existing_config = existing.setdefault("config", {})
        existing_column_types = existing_config.setdefault("column_types", {})
        for column_name, data_type in seed_entry["config"]["column_types"].items():
            existing_column_types.setdefault(column_name, data_type)
        if "meta" in seed_entry:
            existing.setdefault("meta", seed_entry["meta"])

    data["seeds"] = sorted(data["seeds"], key=lambda entry: entry["name"])
    return data


def dump_seed_schema_yml(data: dict) -> str:
    return yaml.safe_dump(
        data,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )


def emit_seed_schema_yml(
    seeds_dir: Path,
    seed_name: str,
    ddl: DdlTable,
    *,
    source_filename: str | None = None,
    force: bool = False,
) -> str:
    data = load_seed_schema_yml(seeds_dir / SEED_SCHEMA_YML_NAME)
    seed_entry = build_seed_schema_entry(
        seed_name,
        ddl,
        source_filename=source_filename,
    )
    merge_seed_schema(data, seed_entry, force=force)
    return dump_seed_schema_yml(data)


# ---------------------------------------------------------------------------
# Sources YAML (emit_sources)
# ---------------------------------------------------------------------------


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
