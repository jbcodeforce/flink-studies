"""Emit and merge dbt schema.yml entries from DDL column types."""

from __future__ import annotations

from pathlib import Path

import yaml

from flink_dbt_migrate.parse_ddl import DdlTable
from flink_dbt_migrate.type_map import flink_type_to_dbt

SCHEMA_YML_NAME = "schema.yml"


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
