"""Emit dbt model SQL from parsed DML and DDL."""

from __future__ import annotations

from flink_dbt_migrate.parse_ddl import DdlTable
from flink_dbt_migrate.parse_dml import DmlStatement
from flink_dbt_migrate.rewrite_refs import collect_cte_names, rewrite_refs


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


def emit_model_sql(
    dml: DmlStatement,
    ddl: DdlTable,
    *,
    materialized: str = "streaming_table",
    ref_overrides: dict[str, str] | None = None,
    source_filename: str | None = None,
) -> str:
    cte_names = collect_cte_names(dml.body)
    body = rewrite_refs(dml.body, cte_names, ref_overrides)

    parts: list[str] = [format_config_block(ddl, materialized=materialized), ""]

    migration_note = source_filename or dml.source_file
    if migration_note:
        parts.append(f"-- Migrated from {migration_note}")

    if dml.leading_comments:
        parts.append(dml.leading_comments)

    parts.append(body)
    return "\n".join(parts) + "\n"
