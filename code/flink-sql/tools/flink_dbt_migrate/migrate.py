"""Orchestrate Flink DML to dbt model migration."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from flink_dbt_migrate.emit_model import emit_model_sql
from flink_dbt_migrate.emit_schema import emit_schema_yml
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import discover_ddl_path, parse_dml


@dataclass(frozen=True)
class MigrationResult:
    model_name: str
    model_sql: str
    schema_yml: str
    model_path: Path
    schema_path: Path
    ddl_path: Path


def migrate_dml_to_dbt(
    statement_file: str | Path,
    target_dir: str | Path,
    *,
    ddl_file: str | Path | None = None,
    model_name: str | None = None,
    materialized: str = "streaming_table",
    ref_overrides: dict[str, str] | None = None,
    force: bool = False,
) -> MigrationResult:
    statement_path = Path(statement_file).resolve()
    target_path = Path(target_dir).resolve()
    dml_text = statement_path.read_text(encoding="utf-8")
    dml = parse_dml(dml_text, source_file=statement_path.name)

    resolved_model_name = model_name or dml.target_table
    ddl_path = Path(
        discover_ddl_path(str(statement_path), dml.target_table, str(ddl_file) if ddl_file else None)
    )
    ddl = parse_ddl(ddl_path.read_text(encoding="utf-8"))

    model_sql = emit_model_sql(
        dml,
        ddl,
        materialized=materialized,
        ref_overrides=ref_overrides,
        source_filename=statement_path.name,
    )
    schema_yml = emit_schema_yml(
        target_path,
        resolved_model_name,
        ddl,
        source_filename=statement_path.name,
        force=force,
    )

    return MigrationResult(
        model_name=resolved_model_name,
        model_sql=model_sql,
        schema_yml=schema_yml,
        model_path=target_path / f"{resolved_model_name}.sql",
        schema_path=target_path / "schema.yml",
        ddl_path=ddl_path,
    )
