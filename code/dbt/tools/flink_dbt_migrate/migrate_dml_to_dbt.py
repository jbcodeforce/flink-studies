#!/usr/bin/env python3
"""Migrate Flink INSERT INTO DML statements to dbt streaming_table models."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Annotated

import typer

from flink_dbt_migrate.compare_sql import compare_migration, format_compare_report
from flink_dbt_migrate.migrate import migrate_dml_to_dbt
from flink_dbt_migrate.parse_dml import parse_dml
from flink_dbt_migrate.temp_write import begin_temp_write, restore_temp_write
from flink_dbt_migrate.validate_compile import (
    DbtCompileError,
    find_dbt_project,
    resolve_ref_aliases,
    validate_compiled_migration,
)


def parse_ref_table(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise typer.BadParameter(f"Expected TABLE=MODEL mapping, got: {value!r}")
    table, model = value.split("=", 1)
    table = table.strip()
    model = model.strip()
    if not table or not model:
        raise typer.BadParameter(f"Expected TABLE=MODEL mapping, got: {value!r}")
    return table, model


def run_validate(
    statement_file: Path,
    result_model_path: Path,
    result_schema_path: Path,
    result_model_sql: str,
    result_schema_yml: str,
    model_name: str,
    target_dir: Path,
    *,
    dbt_project_dir: Path | None,
    dbt_target: str,
    dbt_profiles_dir: Path | None,
    ref_overrides: dict[str, str],
    write: bool,
    sources_path: Path | None,
    sources_yml: str | None,
) -> None:
    should_restore = not write
    temp_state = begin_temp_write(
        result_model_path,
        result_schema_path,
        result_model_sql,
        result_schema_yml,
        sources_path=sources_path,
        sources_yml=sources_yml,
    )

    try:
        project_dir = (
            dbt_project_dir.resolve()
            if dbt_project_dir is not None
            else find_dbt_project(target_dir)
        )
        compile_result = validate_compiled_migration(
            project_dir,
            result_model_path,
            model_name,
            profiles_dir=dbt_profiles_dir,
            target=dbt_target,
            ref_overrides=ref_overrides,
        )
    except (DbtCompileError, FileNotFoundError, ValueError) as exc:
        if should_restore:
            restore_temp_write(temp_state)
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc

    source_text = statement_file.read_text(encoding="utf-8")
    source_dml = parse_dml(source_text, source_file=statement_file.name)
    ref_aliases = resolve_ref_aliases(
        compile_result.project_dir,
        model_name,
        ref_overrides,
    )
    compare_result = compare_migration(
        source_dml,
        compile_result.compiled_sql,
        ref_aliases,
    )

    if should_restore:
        restore_temp_write(temp_state)

    typer.echo(format_compare_report(compare_result))
    if not compare_result.body_match:
        raise typer.Exit(1)


def migrate(
    statement_file: Annotated[
        Path,
        typer.Argument(help="Flink DML file (INSERT INTO ... SELECT)"),
    ],
    target_dir: Annotated[
        Path,
        typer.Argument(help="dbt models subfolder to write {model}.sql and schema.yml"),
    ],
    ddl_file: Annotated[
        Path | None,
        typer.Option("--ddl-file", help="Override auto-discovered DDL file"),
    ] = None,
    model_name: Annotated[
        str | None,
        typer.Option(
            "--model-name",
            help="Output model name (default: INSERT INTO target table)",
        ),
    ] = None,
    materialized: Annotated[
        str,
        typer.Option(
            "--materialized",
            help="dbt materialization (default: streaming_table)",
        ),
    ] = "streaming_table",
    ref_table: Annotated[
        list[str],
        typer.Option(
            "--ref-table",
            metavar="TABLE=MODEL",
            help="Override {{ ref() }} mapping for an upstream table",
        ),
    ] = [],
    write: Annotated[
        bool,
        typer.Option("--write", help="Write output files (default: dry-run to stdout)"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option(
            "--force",
            help="Overwrite existing model and replace schema.yml entry",
        ),
    ] = False,
    check: Annotated[
        bool,
        typer.Option("--check", help="Exit 1 if output would change (for CI)"),
    ] = False,
    validate: Annotated[
        bool,
        typer.Option(
            "--validate",
            help="Run dbt compile and compare compiled SQL to source DML",
        ),
    ] = False,
    dbt_project_dir: Annotated[
        Path | None,
        typer.Option(
            "--dbt-project-dir",
            help="dbt project root (default: auto-discover from target_dir)",
        ),
    ] = None,
    dbt_target: Annotated[
        str,
        typer.Option("--dbt-target", help="dbt target name (default: dev)"),
    ] = "dev",
    dbt_profiles_dir: Annotated[
        Path | None,
        typer.Option(
            "--dbt-profiles-dir",
            help="dbt profiles directory (default: ~/.dbt)",
        ),
    ] = None,
    source_project_dir: Annotated[
        Path | None,
        typer.Option(
            "--source-project-dir",
            help="Flink SQL project to search for upstream DDLs (default: DML file directory)",
        ),
    ] = None,
    source_name: Annotated[
        str | None,
        typer.Option(
            "--source-name",
            help="dbt source group name in sources.yaml (default: sanitized DML folder name)",
        ),
    ] = None,
    no_sources: Annotated[
        bool,
        typer.Option(
            "--no-sources",
            help="Skip upstream source discovery; keep ref()-only rewrite",
        ),
    ] = False,
) -> None:
    if not statement_file.is_file():
        typer.echo(f"Statement file not found: {statement_file}", err=True)
        raise typer.Exit(1)

    ref_overrides = dict(parse_ref_table(item) for item in ref_table)
    profiles_dir = dbt_profiles_dir.expanduser() if dbt_profiles_dir else None
    print('=' * 100)
    print(f"Running migrate_dml_to_dbt with:")
    print(f"  statement_file: {statement_file}")
    print(f"  target_dir: {target_dir}")
    print(f"  ddl_file: {ddl_file}")
    mn=model_name if model_name else 'auto-derived from statement file'
    print(f"  model_name: {mn}")
    print(f"  materialized: {materialized}")
    print(f"  ref_overrides: {ref_overrides}")
    print(f"  force: {force}")
    print(f"  check: {check}")
    print(f"  validate: {validate}")
    if validate:
        print(f"  dbt_project_dir: {dbt_project_dir}")
        print(f"  dbt_target: {dbt_target}")
        print(f"  dbt_profiles_dir: {dbt_profiles_dir}")
    print('=' * 100)
    try:
        result = migrate_dml_to_dbt(
            statement_file,
            target_dir,
            ddl_file=ddl_file,
            model_name=model_name,
            materialized=materialized,
            ref_overrides=ref_overrides,
            force=force,
            source_project_dir=source_project_dir,
            source_name=source_name,
            resolve_sources=not no_sources,
        )
    except (ValueError, FileNotFoundError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc

    existing_model = (
        result.model_path.read_text(encoding="utf-8")
        if result.model_path.exists()
        else ""
    )
    existing_schema = (
        result.schema_path.read_text(encoding="utf-8")
        if result.schema_path.exists()
        else ""
    )
    existing_sources = (
        result.sources_path.read_text(encoding="utf-8")
        if result.sources_path and result.sources_path.exists()
        else ""
    )

    would_change = (
        existing_model != result.model_sql
        or existing_schema != result.schema_yml
        or (result.sources_yml is not None and existing_sources != result.sources_yml)
    )

    if check and would_change:
        typer.echo(
            f"Output differs from {result.model_path} / {result.schema_path}; "
            "run with --write",
            err=True,
        )
        raise typer.Exit(1)

    if write:
        target_dir.mkdir(parents=True, exist_ok=True)
        if result.model_path.exists() and not force:
            typer.echo(
                f"Model already exists: {result.model_path} (use --force to overwrite)",
                err=True,
            )
            raise typer.Exit(1)
        result.model_path.write_text(result.model_sql, encoding="utf-8")
        result.schema_path.write_text(result.schema_yml, encoding="utf-8")
        typer.echo(f"Wrote {result.model_path}")
        typer.echo(f"Wrote {result.schema_path}")
        if result.sources_yml is not None and result.sources_path is not None:
            result.sources_path.parent.mkdir(parents=True, exist_ok=True)
            result.sources_path.write_text(result.sources_yml, encoding="utf-8")
            typer.echo(f"Wrote {result.sources_path}")
        typer.echo(f"DDL source: {result.ddl_path}", err=True)
        if result.upstream_tables:
            typer.echo(
                f"Upstream tables: {', '.join(result.upstream_tables)}",
                err=True,
            )
    elif not validate:
        print("# --- model ---")
        print(result.model_sql, end="")
        print("# --- schema.yml ---")
        print(result.schema_yml, end="")
        if result.sources_yml is not None:
            print("# --- sources.yaml ---")
            print(result.sources_yml, end="")
        print(f"# DDL source: {result.ddl_path}", file=sys.stderr)

    if validate:
        run_validate(
            statement_file,
            result.model_path,
            result.schema_path,
            result.model_sql,
            result.schema_yml,
            result.model_name,
            target_dir,
            dbt_project_dir=dbt_project_dir,
            dbt_target=dbt_target,
            dbt_profiles_dir=profiles_dir,
            ref_overrides=ref_overrides,
            write=write,
            sources_path=result.sources_path,
            sources_yml=result.sources_yml,
        )


app = typer.Typer(add_completion=False)
app.command()(migrate)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
