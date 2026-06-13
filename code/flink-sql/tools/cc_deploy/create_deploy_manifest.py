#!/usr/bin/env python3
"""
Generate deploy_manifest.json from SQL files in a demo folder.

Usage:
  uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../11-puzzles/my_demo
  uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../11-puzzles/my_demo --dry-run
  uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../11-puzzles/my_demo --overwrite
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from cc_deploy.manifest import (
    DEFAULT_MANIFEST,
    create_manifest_from_folder,
    manifest_to_dict,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create deploy_manifest.json template from SQL files in a demo folder."
    )
    parser.add_argument(
        "--sql-dir",
        type=Path,
        required=True,
        help="Demo folder containing SQL files",
    )
    parser.add_argument(
        "--prefix",
        default=None,
        help="Statement name prefix (default: folder name slug)",
    )
    parser.add_argument(
        "--user-agent",
        default=None,
        help="HTTP user agent for Flink API (default: flink-studies-<folder>/0.1)",
    )
    parser.add_argument(
        "--manifest",
        default=DEFAULT_MANIFEST,
        help=f"Manifest filename (default: {DEFAULT_MANIFEST})",
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

    try:
        manifest = create_manifest_from_folder(
            args.sql_dir,
            prefix=args.prefix,
            user_agent=args.user_agent,
            manifest_name=args.manifest,
            write=not args.dry_run,
            overwrite=args.overwrite or args.dry_run,
        )
    except (FileNotFoundError, FileExistsError, NotADirectoryError, ValueError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    payload = manifest_to_dict(manifest)
    print(json.dumps(payload, indent=2))

    if args.dry_run:
        print(f"\n(dry-run: not written to {args.sql_dir / args.manifest})", file=sys.stderr)
    else:
        print(f"\nWrote {args.sql_dir / args.manifest}", file=sys.stderr)


if __name__ == "__main__":
    main()
