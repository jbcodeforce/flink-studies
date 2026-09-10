#!/usr/bin/env python3
"""
Generate deploy_manifest.json from SQL files in a demo folder,
or from a dbt-confluent project (use --dbt).

Usage:
  # Raw SQL folder
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --dry-run
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --overwrite

  # dbt project  (requires: uv sync --extra dbt)
  uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming --dbt
  uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming --dbt --dry-run
  uv run python -m manifest.manifest_cli --sql-dir code/dbt/airbnb_streaming --dbt --overwrite
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Optional

import typer

from manifest.manifest import (
    DEFAULT_MANIFEST,
    create_manifest_from_dbt_folder,
    create_manifest_from_folder,
    _find_dbt_project_root,
)

app = typer.Typer(
    add_completion=False,
    help="Create deploy_manifest.json template from Flink SQL files or a dbt project.",
)


@app.command()
def main(
    sql_dir: Path = typer.Option(
        ...,
        "--sql-dir",
        help="Folder containing Flink SQL files, or dbt project root when --dbt is set",
    ),
    prefix: Optional[str] = typer.Option(
        None,
        "--prefix",
        help="Statement name prefix (default: folder name slug). Ignored in --dbt mode.",
    ),
    overwrite: bool = typer.Option(
        False,
        "--overwrite",
        help="Replace an existing manifest file",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Print manifest JSON without writing a file",
    ),
    dbt: bool = typer.Option(
        False,
        "--dbt",
        help=(
            "Generate manifest from a dbt-confluent project. "
            "Auto-discovers the project root by searching for dbt_project.yml or "
            "sl_dbt.yaml starting from --sql-dir. "
            "Requires: uv sync --extra dbt"
        ),
    ),
) -> None:
    if dbt:
        try:
            project_root = _find_dbt_project_root(sql_dir)
        except FileNotFoundError as exc:
            print(exc, file=sys.stderr)
            raise typer.Exit(code=1) from exc

        manifest_path = project_root / DEFAULT_MANIFEST

        try:
            manifest = create_manifest_from_dbt_folder(
                project_root,
                write=not dry_run,
                overwrite=overwrite,
            )
        except (
            FileNotFoundError,
            FileExistsError,
            NotADirectoryError,
            ValueError,
            ImportError,
        ) as exc:
            print(exc, file=sys.stderr)
            raise typer.Exit(code=1) from exc

    else:
        manifest_path = sql_dir / DEFAULT_MANIFEST

        try:
            manifest = create_manifest_from_folder(
                sql_dir,
                prefix=prefix,
                write=not dry_run,
                overwrite=overwrite,
            )
        except (FileNotFoundError, FileExistsError, NotADirectoryError, ValueError) as exc:
            print(exc, file=sys.stderr)
            raise typer.Exit(code=1) from exc

    print(json.dumps(manifest.model_dump(exclude_none=True), indent=2))

    if dry_run:
        print(f"\n(dry-run: not written to {manifest_path})", file=sys.stderr)
    else:
        print(f"\nWrote {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    app()
