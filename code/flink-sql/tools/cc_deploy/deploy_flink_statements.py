#!/usr/bin/env python3
"""
Generic CLI to deploy Flink SQL statement groups via confluent-sql (REST API).

Usage:
  uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update deploy --group all
  uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update undeploy --group all
  uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../11-puzzles/cart_update drop-tables
  uv run python -m cc_deploy.deploy_flink_statements --sql-dir ../04-joins/cc groups

Each demo folder supplies deploy_manifest.json listing statement groups, SQL files,
undeploy_all order, and drop_tables for full teardown.
Environment: see cc_deploy.flink_deploy (loads ~/.confluent/.env by default).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from cc_deploy import (
    DEFAULT_MANIFEST,
    deploy_statements,
    drop_tables,
    full_undeploy,
    get_config,
    load_dotenv_file,
    load_manifest,
    undeploy_statements,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deploy Flink SQL statement groups to Confluent Cloud (confluent-sql REST API)."
    )
    parser.add_argument(
        "--sql-dir",
        type=Path,
        required=True,
        help="Demo folder containing SQL files and deploy_manifest.json",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help=f"Manifest path (default: <sql-dir>/{DEFAULT_MANIFEST})",
    )
    sub = parser.add_subparsers(dest="action", required=True)

    deploy_p = sub.add_parser("deploy", help="Create statements in manifest order")
    deploy_p.add_argument(
        "--group",
        default="all",
        help="Manifest group name, or 'all' (default: all)",
    )

    undeploy_p = sub.add_parser(
        "undeploy",
        help="Delete statements; with --group all also drops tables from manifest",
    )
    undeploy_p.add_argument(
        "--group",
        default="all",
        help="Manifest group name, or 'all' for full teardown (default: all)",
    )
    undeploy_p.add_argument(
        "--no-drop-tables",
        action="store_true",
        help="With --group all, delete statements only (skip drop_tables)",
    )

    sub.add_parser(
        "drop-tables",
        help="Drop tables listed in manifest drop_tables (no statement deletes)",
    )

    sub.add_parser(
        "groups",
        help="List manifest groups and statement counts",
    )

    return parser.parse_args()


def print_groups(manifest) -> None:
    """Print group names, sizes, and deploy_all / undeploy_all membership."""
    deploy_set = set(manifest.deploy_all)
    undeploy_set = set(manifest.undeploy_all)
    for name in sorted(manifest.groups):
        count = len(manifest.groups[name])
        flags: list[str] = []
        if name in deploy_set:
            flags.append("deploy_all")
        if name in undeploy_set:
            flags.append("undeploy_all")
        flag_text = f" ({', '.join(flags)})" if flags else ""
        print(f"{name}: {count} statement(s){flag_text}")


def main() -> None:
    load_dotenv_file()
    args = parse_args()

    sql_dir = args.sql_dir.resolve()
    if not sql_dir.is_dir():
        print(f"sql-dir not found: {sql_dir}", file=sys.stderr)
        sys.exit(1)

    manifest_path = (args.manifest or sql_dir / DEFAULT_MANIFEST).resolve()
    if not manifest_path.is_file():
        print(f"Manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    manifest = load_manifest(manifest_path)

    if args.action == "groups":
        print_groups(manifest)
        return

    config = get_config()

    try:
        if args.action == "deploy":
            group = args.group
            statements = manifest.statements_for(group)
            deploy_statements(
                statements,
                sql_dir=sql_dir,
                config=config,
                user_agent=manifest.user_agent,
            )
            print(f"deploy --group {group} complete.")
            return

        if args.action == "drop-tables":
            if not manifest.drop_tables:
                print("No drop_tables defined in manifest.", file=sys.stderr)
                sys.exit(1)
            drop_tables(manifest.drop_tables, manifest=manifest, config=config)
            print("drop-tables complete.")
            return

        group = args.group
        if group == "all":
            full_undeploy(
                manifest,
                config=config,
                drop_tables_after=not args.no_drop_tables,
            )
        else:
            statements = manifest.undeploy_order(group)
            undeploy_statements(
                statements,
                config=config,
                user_agent=manifest.user_agent,
            )
        print(f"undeploy --group {group} complete.")
    except KeyError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
