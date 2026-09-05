"""Emit dbt CSV seed files and seed schema.yml entries from parsed VALUES DML."""

from __future__ import annotations

import csv
import io
from pathlib import Path

import yaml

from flink_dbt_migrate.parse_ddl import DdlTable
from flink_dbt_migrate.type_map import flink_type_to_dbt

SEED_SCHEMA_YML_NAME = "schema.yml"


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
