"""Orchestrate Flink DML to dbt model migration."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from flink_dbt_migrate.discover_deps import (
    default_source_name,
    resolve_upstream_deps,
)
from flink_dbt_migrate.emit_model import emit_model_sql
from flink_dbt_migrate.emit_schema import emit_schema_yml
from flink_dbt_migrate.emit_seed import emit_seed_csv, emit_seed_schema_yml
from flink_dbt_migrate.emit_sources import SOURCES_YML_NAME, emit_sources_yml
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import discover_ddl_path, parse_dml, parse_values_dml
from flink_dbt_migrate.validate_compile import find_dbt_project


@dataclass(frozen=True)
class MigrationResult:
    model_name: str
    model_sql: str
    schema_yml: str
    model_path: Path
    schema_path: Path
    ddl_path: Path
    sources_yml: str | None
    sources_path: Path | None
    upstream_tables: list[str]


def migrate_dml_to_dbt(
    statement_file: str | Path,
    target_dir: str | Path,
    *,
    ddl_file: str | Path | None = None,
    model_name: str | None = None,
    materialized: str = "streaming_table",
    ref_overrides: dict[str, str] | None = None,
    force: bool = False,
    source_project_dir: Path | None = None,
    source_name: str | None = None,
    resolve_sources: bool = True,
    upstream_ddl_map: dict[str, Path] | None = None,
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

    source_project = (source_project_dir or statement_path.parent).resolve()
    resolved_source_name = source_name or default_source_name(source_project)

    dbt_project_dir: Path | None = None
    sources_path: Path | None = None
    sources_yml: str | None = None
    try:
        dbt_project_dir = find_dbt_project(target_path)
        sources_path = dbt_project_dir / "models" / SOURCES_YML_NAME
    except FileNotFoundError:
        sources_path = None

    upstream_deps = resolve_upstream_deps(
        source_project,
        dbt_project_dir,
        dml,
        ref_overrides=ref_overrides,
        source_name=resolved_source_name,
        resolve_sources=resolve_sources,
        upstream_ddl_map=upstream_ddl_map,
    )

    model_sql = emit_model_sql(
        dml,
        ddl,
        materialized=materialized,
        ref_overrides=ref_overrides,
        upstream_deps=upstream_deps,
        source_filename=statement_path.name,
    )
    schema_yml = emit_schema_yml(
        target_path,
        resolved_model_name,
        ddl,
        source_filename=statement_path.name,
        force=force,
    )

    if dbt_project_dir is not None and resolve_sources:
        sources_yml = emit_sources_yml(
            dbt_project_dir / "models",
            resolved_source_name,
            upstream_deps,
            force=force,
        )

    return MigrationResult(
        model_name=resolved_model_name,
        model_sql=model_sql,
        schema_yml=schema_yml,
        model_path=target_path / f"{resolved_model_name}.sql",
        schema_path=target_path / "schema.yml",
        ddl_path=ddl_path,
        sources_yml=sources_yml,
        sources_path=sources_path,
        upstream_tables=[dep.table_name for dep in upstream_deps],
    )


@dataclass(frozen=True)
class SeedMigrationResult:
    seed_name: str
    csv_text: str
    schema_yml: str
    csv_path: Path
    schema_path: Path
    ddl_path: Path


def migrate_values_dml_to_seed(
    statement_file: str | Path,
    seeds_dir: str | Path,
    *,
    ddl_file: str | Path | None = None,
    seed_name: str | None = None,
    force: bool = False,
) -> SeedMigrationResult:
    statement_path = Path(statement_file).resolve()
    seeds_path = Path(seeds_dir).resolve()
    dml_text = statement_path.read_text(encoding="utf-8")
    values_dml = parse_values_dml(dml_text, source_file=statement_path.name)

    resolved_seed_name = seed_name or values_dml.target_table
    ddl_path = Path(
        discover_ddl_path(
            str(statement_path),
            values_dml.target_table,
            str(ddl_file) if ddl_file else None,
        )
    )
    ddl = parse_ddl(ddl_path.read_text(encoding="utf-8"))

    if values_dml.columns:
        columns = values_dml.columns
    else:
        columns = [column.name for column in ddl.columns]
        if values_dml.rows and len(values_dml.rows[0]) != len(columns):
            raise ValueError(
                f"INSERT INTO {values_dml.target_table} VALUES has "
                f"{len(values_dml.rows[0])} values per row but the DDL declares "
                f"{len(columns)} columns; provide an explicit column list"
            )

    csv_text = emit_seed_csv(columns, values_dml.rows)
    schema_yml = emit_seed_schema_yml(
        seeds_path,
        resolved_seed_name,
        ddl,
        source_filename=statement_path.name,
        force=force,
    )

    return SeedMigrationResult(
        seed_name=resolved_seed_name,
        csv_text=csv_text,
        schema_yml=schema_yml,
        csv_path=seeds_path / f"{resolved_seed_name}.csv",
        schema_path=seeds_path / "schema.yml",
        ddl_path=ddl_path,
    )
