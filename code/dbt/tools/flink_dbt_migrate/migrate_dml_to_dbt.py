#!/usr/bin/env python3
"""Migrate Flink INSERT INTO DML statements to dbt streaming_table models."""

from __future__ import annotations

from dataclasses import asdict
import sys
import json
from pathlib import Path
from typing import Annotated
import typer

from flink_dbt_migrate.sl_discovery_mgr import crawl_pipeline_folder
from flink_dbt_migrate.migrate import (
    migrate_dml_to_dbt,
    migrate_values_dml_to_seed,
)
from flink_dbt_migrate.flink_sql_processor import (
    is_values_insert,
        _get_logger,
)


app = typer.Typer(add_completion=False)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_ref_table(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise typer.BadParameter(f"Expected TABLE=MODEL mapping, got: {value!r}")
    table, model = value.split("=", 1)
    table = table.strip()
    model = model.strip()
    if not table or not model:
        raise typer.BadParameter(f"Expected TABLE=MODEL mapping, got: {value!r}")
    return table, model


def run_migrate_seed(
    statement_file: Path,
    seeds_dir: Path,
    *,
    ddl_file: Path | None,
    seed_name: str | None,
    write: bool,
    force: bool,
    check: bool,
) -> None:
    _get_logger().info(
        "run_migrate_seed | statement_file=%s seeds_dir=%s seed_name=%s write=%s force=%s check=%s",
        statement_file, seeds_dir, seed_name, write, force, check,
    )
    try:
        result = migrate_values_dml_to_seed(
            statement_file,
            seeds_dir,
            ddl_file=ddl_file,
            seed_name=seed_name,
            force=force,
        )
    except (ValueError, FileNotFoundError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc

    existing_csv = (
        result.csv_path.read_text(encoding="utf-8") if result.csv_path.exists() else ""
    )
    existing_schema = (
        result.schema_path.read_text(encoding="utf-8")
        if result.schema_path.exists()
        else ""
    )
    would_change = existing_csv != result.csv_text or existing_schema != result.schema_yml

    if check and would_change:
        typer.echo(
            f"Output differs from {result.csv_path} / {result.schema_path}; run with --write",
            err=True,
        )
        raise typer.Exit(1)

    if write:
        seeds_dir.mkdir(parents=True, exist_ok=True)
        if result.csv_path.exists() and not force:
            typer.echo(
                f"Seed already exists: {result.csv_path} (use --force to overwrite)",
                err=True,
            )
            raise typer.Exit(1)
        result.csv_path.write_text(result.csv_text, encoding="utf-8")
        result.schema_path.write_text(result.schema_yml, encoding="utf-8")
        typer.echo(f"Wrote {result.csv_path}")
        typer.echo(f"Wrote {result.schema_path}")
        typer.echo(f"DDL source: {result.ddl_path}", err=True)
    else:
        print("# --- seed csv ---")
        print(result.csv_text, end="")
        print("# --- schema.yml ---")
        print(result.schema_yml, end="")
        print(f"# DDL source: {result.ddl_path}", file=sys.stderr)


# ---------------------------------------------------------------------------
# CLI commands
# ---------------------------------------------------------------------------

@app.command()
def migrate_sl_folder(
    pipeline_dir: Annotated[
        Path,
        typer.Argument(help="Shift-left pipelines folder (or sub-folder) to crawl"),
    ],
    dbt_project_dir: Annotated[
        Path,
        typer.Argument(help="dbt project root; models are written under models/"),
    ],
    write: Annotated[
        bool,
        typer.Option("--write", help="Write output files (default: dry-run)"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option("--force", help="Overwrite existing models and schema.yml entries"),
    ] = False,
) -> None:
    """Crawl a shift-left pipelines folder and migrate every table to dbt.

    Each table must have a ``sql_scripts/`` directory containing ``ddl.{table}.sql``
    and ``dml.{table}.sql``.  The source hierarchy is mirrored into the dbt project:

        pipelines/dimensions/customer/  →  dbt_project/models/dimensions/customer/
    """
    _get_logger().info(
        "migrate_sl_folder | pipeline_dir=%s dbt_project_dir=%s write=%s force=%s",
        pipeline_dir, dbt_project_dir, write, force,
    )
    pipeline_dir = pipeline_dir.resolve()
    dbt_project_dir = dbt_project_dir.resolve()

    if not pipeline_dir.is_dir():
        typer.echo(f"Pipeline directory not found: {pipeline_dir}", err=True)
        raise typer.Exit(1)

    typer.echo(f"Crawling {pipeline_dir} ...")
    entries = crawl_pipeline_folder(pipeline_dir)

    if not entries:
        typer.echo("No tables discovered (no sql_scripts/ directories with dml.*.sql found).")
        raise typer.Exit(0)

    # Print inventory
    typer.echo(f"\nDiscovered {len(entries)} table(s):")
    col = max(len(e.table_name) for e in entries)
    for e in entries:
        typer.echo(f"  {e.table_name:<{col}} ({e.relative_path}) seed: {e.is_seed}")
    typer.echo("")

    if not write:
        typer.echo("Dry-run mode — pass --write to generate dbt model files.")
        raise typer.Exit(0)

    models_root = dbt_project_dir / "models"
    seeds_root = dbt_project_dir / "seeds"
    migrated = 0
    failures: list[tuple[str, str]] = []

    for entry in entries:
        if entry.is_seed:
            try:
                seed_result = migrate_values_dml_to_seed(
                    entry.dml_path,
                    seeds_root,
                    ddl_file=entry.ddl_path,
                    force=force,
                )
                seeds_root.mkdir(parents=True, exist_ok=True)
                seed_result.csv_path.write_text(seed_result.csv_text, encoding="utf-8")
                seed_result.schema_path.write_text(seed_result.schema_yml, encoding="utf-8")
                typer.echo(
                    f"  ✓  {entry.table_name}: wrote {seed_result.csv_path.relative_to(dbt_project_dir)}"
                )
                migrated += 1
            except Exception as exc:  # noqa: BLE001
                failures.append((entry.table_name, str(exc)))
                typer.echo(f"  ✗  {entry.table_name}: {exc}", err=True)
            continue

        target_dir = models_root / entry.relative_path
        try:
            result = migrate_dml_to_dbt(
                entry.dml_path,
                target_dir,
                ddl_file=entry.ddl_path,
                force=force,
                upstream_ddl_map=entry.upstream_ddl_map,
            )
            target_dir.mkdir(parents=True, exist_ok=True)
            result.model_path.write_text(result.model_sql, encoding="utf-8")
            result.schema_path.write_text(result.schema_yml, encoding="utf-8")
            typer.echo(f"  ✓  {entry.table_name}: wrote {result.model_path.relative_to(dbt_project_dir)}")
            if result.sources_yml is not None and result.sources_path is not None:
                result.sources_path.parent.mkdir(parents=True, exist_ok=True)
                result.sources_path.write_text(result.sources_yml, encoding="utf-8")
            migrated += 1
        except Exception as exc:  # noqa: BLE001
            failures.append((entry.table_name, str(exc)))
            typer.echo(f"  ✗  {entry.table_name}: {exc}", err=True)

    typer.echo(f"\n{migrated} migrated, {len(failures)} failed.")
    if failures:
        raise typer.Exit(1)


@app.command()
def migrate_one_file(
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
    seed_name: Annotated[
        str | None,
        typer.Option(
            "--seed-name",
            help="Output seed name for INSERT INTO ... VALUES files "
            "(default: INSERT INTO target table)",
        ),
    ] = None,
) -> None:
    _get_logger().info(
        "migrate_one_file | statement_file=%s target_dir=%s model_name=%s "
        "materialized=%s write=%s force=%s check=%s no_sources=%s",
        statement_file, target_dir, model_name, materialized, write, force, check, no_sources,
    )
    if not statement_file.is_file():
        typer.echo(f"Statement file not found: {statement_file}", err=True)
        raise typer.Exit(1)
    print()
    print('=' * 40, " INPUT ", "=" * 20)
    print(f"Running migrate_dml_to_dbt with:")
    print(f"  statement_file: {statement_file}")
    print(f"  target_dir: {target_dir}")
    print(f"  ddl_file: {ddl_file}")
    mn=model_name if model_name else 'auto-derived from statement file'
    print(f"  model_name: {mn}")
    print(f"  materialized: {materialized}")
    print(f"  force: {force}")
    print(f"  check: {check}")
    print(f"  dbt_project_dir: {dbt_project_dir}")
    print(f"  dbt_target: {dbt_target}")
    print(f"  dbt_profiles_dir: {dbt_profiles_dir}")
    print(f"  source_project_dir: {source_project_dir}")
    print(f"  source_name: {source_name}")
    print(f"  no_sources: {no_sources}")
    print(f"  seed_name: {seed_name}")
    if is_values_insert(statement_file.read_text(encoding="utf-8")):
        run_migrate_seed(
            statement_file,
            target_dir,
            ddl_file=ddl_file,
            seed_name=seed_name or model_name,
            write=write,
            force=force,
            check=check,
        )
        return

    ref_overrides = dict(parse_ref_table(item) for item in ref_table)
    profiles_dir = dbt_profiles_dir.expanduser() if dbt_profiles_dir else None
    print(f"  ref_overrides: {ref_overrides}")
    print('=' * 100)
    try:
        result = migrate_dml_to_dbt(
            statement_file,
            target_dir,
            ddl_file=ddl_file,
            model_name=model_name,
            materialized=materialized,
            ref_overrides=ref_overrides,
            dbt_project_dir=dbt_project_dir,
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
    typer.echo(f"result= {result}")
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

    print("# --- model ---")
    print(result.model_sql, end="")
    print("# --- schema.yml ---")
    print(result.schema_yml, end="")
    if result.sources_yml is not None:
        print("# --- sources.yaml ---")
        print(result.sources_yml, end="")
    print(f"# DDL source: {result.ddl_path}", file=sys.stderr)



if __name__ == "__main__":
    app()
