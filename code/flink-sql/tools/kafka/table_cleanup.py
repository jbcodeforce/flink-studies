#!/usr/bin/env python3
"""
List Kafka topics into an editable drop manifest, then drop Flink SQL tables.

Usage:
  uv run python -m cc_deploy.table_cleanup list --output drop_tables_manifest.json
  uv run python -m cc_deploy.table_cleanup list --dry-run
  uv run python -m cc_deploy.table_cleanup drop --manifest drop_tables_manifest.json
  uv run python -m cc_deploy.table_cleanup drop --manifest drop_tables_manifest.json --dry-run

Environment: ~/.confluent/.env (override with CONFLUENT_ENV_FILE).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from cc_deploy.drop_tables_manifest import (
    DEFAULT_MANIFEST_NAME,
    build_manifest_from_topics,
    load_manifest,
    tables_to_drop,
    write_manifest,
)
from cc_deploy.flink_deploy import drop_tables_by_name, get_config, load_dotenv_file
from cc_deploy.kafka_client import list_topics


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List Kafka topics into a drop manifest and drop Flink SQL tables."
    )
    sub = parser.add_subparsers(dest="action", required=True)

    list_p = sub.add_parser("list", help="List Kafka topics and write drop manifest JSON")
    list_p.add_argument(
        "--output",
        type=Path,
        default=Path(DEFAULT_MANIFEST_NAME),
        help=f"Output manifest path (default: {DEFAULT_MANIFEST_NAME})",
    )
    list_p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print manifest JSON without writing a file",
    )
    list_p.add_argument(
        "--include-internal",
        action="store_true",
        help="Include internal topics (__consumer_offsets, _*) in the manifest",
    )
    list_p.add_argument(
        "--statement-prefix",
        default=None,
        help="Prefix for ephemeral DROP TABLE statement names (default: cleanup-drop)",
    )

    drop_p = sub.add_parser("drop", help="Drop Flink tables listed in manifest")
    drop_p.add_argument(
        "--manifest",
        type=Path,
        default=Path(DEFAULT_MANIFEST_NAME),
        help=f"Drop manifest path (default: {DEFAULT_MANIFEST_NAME})",
    )
    drop_p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print DROP TABLE statements without calling Flink API",
    )

    return parser.parse_args()


def cmd_list(args: argparse.Namespace) -> None:
    load_dotenv_file()
    topics = list_topics(exclude_internal=not args.include_internal)

    bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "")
    database = os.environ.get("FLINK_DATABASE_NAME")
    prefix = args.statement_prefix or "cleanup-drop"
    manifest = build_manifest_from_topics(
        topics,
        bootstrap_servers=bootstrap,
        database=database,
        statement_prefix=prefix,
    )
    payload = json.dumps(manifest, indent=2)

    if args.dry_run:
        print(payload)
        print(f"\n(dry-run: not written to {args.output})", file=sys.stderr)
        return

    write_manifest(manifest, args.output.resolve())
    print(payload)
    print(f"\nWrote {args.output.resolve()}", file=sys.stderr)
    print(
        "Edit the manifest (set drop: false or remove rows) before running drop.",
        file=sys.stderr,
    )


def cmd_drop(args: argparse.Namespace) -> None:
    load_dotenv_file()
    manifest_path = args.manifest.resolve()
    if not manifest_path.is_file():
        print(f"Manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    entries, raw = load_manifest(manifest_path)
    tables = tables_to_drop(entries)
    if not tables:
        print("No tables marked for drop in manifest.", file=sys.stderr)
        sys.exit(1)

    prefix = raw.get("statement_prefix") or "cleanup-drop"
    if args.dry_run:
        for table in tables:
            print(f"DROP TABLE IF EXISTS {table}")
        print(f"\n(dry-run: {len(tables)} table(s), no API calls)", file=sys.stderr)
        return

    config = get_config()
    drop_tables_by_name(
        tables,
        config=config,
        statement_prefix=prefix,
    )
    print(f"drop complete ({len(tables)} table(s)).")


def main() -> None:
    args = parse_args()
    if args.action == "list":
        cmd_list(args)
    elif args.action == "drop":
        cmd_drop(args)


if __name__ == "__main__":
    main()
