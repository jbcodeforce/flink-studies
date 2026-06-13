#!/usr/bin/env python3
"""
Deploy cc-flink SQL to Confluent Cloud via cc_deploy (confluent-sql REST API).

Prefer Make targets from 00-basic-sql/:
  make sync && make deploy-employees
  make deploy-customers
  make undeploy

This script is a thin wrapper for the employees walkthrough and snapshot query.

Environment: ~/.confluent/.env (see tools/cc_deploy/flink_deploy.py).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent / "tools"
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from cc_deploy import (  # noqa: E402
    DEFAULT_MANIFEST,
    deploy_statements,
    full_undeploy,
    get_config,
    load_dotenv_file,
    load_manifest,
    print_snapshot_result,
    run_snapshot_query,
)

CC_FLINK = Path(__file__).resolve().parent / "cc-flink"
SNAPSHOT_SQL = "SELECT * FROM employee_count"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deploy cc-flink employees demo via cc_deploy (Confluent Cloud Flink REST API).",
    )
    parser.add_argument(
        "--employees-only",
        action="store_true",
        help="Deploy the employees vertical slice (ddl + insert + employee_count pipeline).",
    )
    parser.add_argument(
        "--customers-only",
        action="store_true",
        help="Deploy the customers vertical slice (ddl + insert + dedup pipeline).",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Deploy full manifest (ddl, data, pipeline for customers and employees).",
    )
    parser.add_argument(
        "--snapshot-query-only",
        action="store_true",
        help="Run a snapshot query on employee_count.",
    )
    parser.add_argument(
        "--delete-only",
        action="store_true",
        help="Stop statements and drop tables from deploy_manifest.json.",
    )
    return parser.parse_args()


def _load() -> tuple:
    load_dotenv_file()
    manifest_path = CC_FLINK / DEFAULT_MANIFEST
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")
    manifest = load_manifest(manifest_path)
    config = get_config()
    return manifest, config


def main() -> None:
    args = parse_args()
    manifest, config = _load()

    if args.snapshot_query_only:
        result = run_snapshot_query(SNAPSHOT_SQL, config=config, user_agent=manifest.user_agent)
        print_snapshot_result(result)
        return

    if args.delete_only:
        full_undeploy(manifest, config=config, drop_tables_after=True)
        print("Teardown complete.")
        return

    if args.customers_only:
        group = "customers"
    elif args.all:
        statements = manifest.statements_for("all")
        deploy_statements(
            statements,
            sql_dir=CC_FLINK,
            config=config,
            user_agent=manifest.user_agent,
        )
        print("Deploy complete (all groups).")
        return
    else:
        # Default: employees walkthrough (same as make deploy-employees)
        group = "employees"

    statements = manifest.statements_for(group)
    deploy_statements(
        statements,
        sql_dir=CC_FLINK,
        config=config,
        user_agent=manifest.user_agent,
    )
    print(f"Deploy complete ({group}).")

    if group == "employees" and not (args.customers_only or args.all):
        result = run_snapshot_query(SNAPSHOT_SQL, config=config, user_agent=manifest.user_agent)
        print_snapshot_result(result)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
