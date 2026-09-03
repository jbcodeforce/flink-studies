#!/usr/bin/env python3
"""
Generate deploy_manifest.json from SQL files in a demo folder.

Usage:
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --dry-run
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --overwrite
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Optional

import typer

from manifest.manifest import DEFAULT_MANIFEST, create_manifest_from_folder

app = typer.Typer(
    add_completion=False,
    help="Create deploy_manifest.json template from Flink SQL files in a folder.",
)


@app.command()
def main(
    sql_dir: Path = typer.Option(
        ...,
        "--sql-dir",
        help="Folder containing Flink SQL files",
    ),
    prefix: Optional[str] = typer.Option(
        None,
        "--prefix",
        help="Statement name prefix (default: folder name slug)",
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
) -> None:
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
