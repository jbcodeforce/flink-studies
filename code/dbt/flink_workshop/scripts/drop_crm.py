#!/usr/bin/env python3
"""
Teardown CRM Flink workshop resources deployed via dbt-confluent.

Stops/deletes Flink statements and drops tables using cc_deploy helpers.

Usage:
  uv run python drop_crm.py teardown
  uv run python drop_crm.py undeploy
  uv run python drop_crm.py drop-tables

Run from code/flink-sql/tools (see flink_workshop/Makefile) or:
  cd code/flink-sql/tools && uv run python ../../dbt/flink_workshop/scripts/drop_crm.py teardown

Environment: ~/.confluent/.env (override with CONFLUENT_ENV_FILE). See cc_deploy.flink_deploy.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

WORKSHOP_DIR = Path(__file__).resolve().parents[1]
TOOLS_DIR = WORKSHOP_DIR.parents[1] / "flink-sql" / "tools"
DEFAULT_MANIFEST_NAME = "teardown_manifest.json"

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from cc_deploy import (  # noqa: E402
    drop_tables,
    full_undeploy,
    get_config,
    load_dotenv_file,
    load_manifest,
    undeploy_statements,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Teardown CRM Flink workshop (dbt-confluent) on Confluent Cloud."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=WORKSHOP_DIR / DEFAULT_MANIFEST_NAME,
        help=f"Teardown manifest path (default: {DEFAULT_MANIFEST_NAME} in workshop root)",
    )
    sub = parser.add_subparsers(dest="action", required=True)

    sub.add_parser(
        "teardown",
        help="Delete Flink statements, then drop tables (full reset)",
    )
    sub.add_parser(
        "undeploy",
        help="Delete Flink statements only (skip drop_tables)",
    )
    sub.add_parser(
        "drop-tables",
        help="Drop tables listed in manifest (no statement deletes)",
    )

    return parser.parse_args()


def main() -> None:
    load_dotenv_file()
    args = parse_args()

    manifest_path = args.manifest.resolve()
    if not manifest_path.is_file():
        print(f"Manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    manifest = load_manifest(manifest_path)
    config = get_config()

    try:
        if args.action == "teardown":
            full_undeploy(manifest, config=config, drop_tables_after=True)
            print("teardown complete.")
            return

        if args.action == "drop-tables":
            if not manifest.drop_tables:
                print("No drop_tables defined in manifest.", file=sys.stderr)
                sys.exit(1)
            drop_tables(manifest.drop_tables, manifest=manifest, config=config)
            print("drop-tables complete.")
            return

        statements = manifest.statements_for_full_undeploy()
        if not statements:
            print("No statements defined in manifest.", file=sys.stderr)
            sys.exit(1)
        print("Stopping and deleting Flink statements...")
        undeploy_statements(
            statements,
            config=config,
            user_agent=manifest.user_agent,
        )
        print("undeploy complete.")
    except KeyError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
