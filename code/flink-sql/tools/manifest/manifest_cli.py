#!/usr/bin/env python3
"""
Generate deploy_manifest.json from SQL files in a demo folder.

Usage:
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --dry-run
  uv run python -m manifest.manifest_cli --sql-dir path/to/demo --overwrite
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from manifest.manifest import DEFAULT_MANIFEST, create_manifest_from_folder


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create deploy_manifest.json template from Flink SQL files in a folder."
    )
    parser.add_argument(
        "--sql-dir",
        type=Path,
        required=True,
        help="Folder containing Flink SQL files",
    )
    parser.add_argument(
        "--prefix",
        default=None,
        help="Statement name prefix (default: folder name slug)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace an existing manifest file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print manifest JSON without writing a file",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest_path = args.sql_dir / DEFAULT_MANIFEST

    try:
        manifest = create_manifest_from_folder(
            args.sql_dir,
            prefix=args.prefix,
            write=not args.dry_run,
            overwrite=args.overwrite,
        )
    except (FileNotFoundError, FileExistsError, NotADirectoryError, ValueError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    print(json.dumps(manifest.model_dump(exclude_none=True), indent=2))

    if args.dry_run:
        print(f"\n(dry-run: not written to {manifest_path})", file=sys.stderr)
    else:
        print(f"\nWrote {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
