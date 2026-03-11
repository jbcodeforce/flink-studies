#!/usr/bin/env python3
"""
Deploy raw DDLs and insert test data to Confluent Cloud Flink via REST API.

Deploys DDLs from raw_topic_for_tests/ (raw_accounts, raw_transactions) and then
runs the insert statements. No Confluent CLI required.

Required env vars (see code/flink-sql/tools/cc_flink_rest_client.py):
  FLINK_API_KEY, FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY, CONFLUENT_CLOUD_API_SECRET)
  ORGANIZATION_ID, ENVIRONMENT_ID, COMPUTE_POOL_ID
  FLINK_BASE_URL (e.g. https://flink.us-west-2.aws.confluent.cloud)
    or REGION + CLOUD (e.g. us-west-2, aws)

Run from the demo root (e2e-demos/cdc-tableapi-to-silver) with uv:
  uv sync && uv run python deploy_raw_data.py [--ddl-only | --insert-only | --drop-tables]
"""

import argparse
import sys
from pathlib import Path

# Add code/flink-sql so we can import tools.cc_flink_rest_client
_repo_root = Path(__file__).resolve().parent.parent.parent
_flink_sql = _repo_root / "code" / "flink-sql"
if str(_flink_sql) not in sys.path:
    sys.path.insert(0, str(_flink_sql))

from tools.cc_flink_rest_client import run_ddl, run_dml, run_query_no_results  # type: ignore[import-untyped]

SCRIPT_DIR = Path(__file__).resolve().parent.parent / "raw_topic_for_tests"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deploy raw DDLs and insert test data to Confluent Cloud Flink via REST API.",
    )
    parser.add_argument(
        "--ddl-only",
        action="store_true",
        help="Deploy only DDLs (raw_accounts, raw_transactions tables).",
    )
    parser.add_argument(
        "--insert-only",
        action="store_true",
        help="Run only insert statements (requires DDLs already deployed).",
    )
    parser.add_argument(
        "--drop-tables",
        action="store_true",
        help="Drop raw_accounts and raw_transactions tables (IF EXISTS).",
    )
    args = parser.parse_args()

    if args.drop_tables:
        print("=== Dropping tables ===")
        run_query_no_results("drop-raw-transactions", "DROP TABLE  raw_transactions;")
        run_query_no_results("drop-raw-accounts", "DROP TABLE raw_accounts;")
        print("Done.")
        return

    if args.ddl_only:
        print("=== Deploying DDLs ===")
        run_ddl("ddl-raw-accounts", SCRIPT_DIR, "ddl.raw_accounts.sql")
        run_ddl("ddl-raw-transactions", SCRIPT_DIR, "ddl.raw_transactions.sql")
        print("Done.")
        return

    if args.insert_only:
        print("=== Running inserts ===")
        run_dml("insert-raw-accounts-1", SCRIPT_DIR, "insert_raw_accounts_1.sql", delete_after=True)
        run_dml("insert-raw-transactions-1", SCRIPT_DIR, "insert_raw_transactions_1.sql", delete_after=True)
        print("Done.")
        return

    # Full flow: DDLs then inserts
    print("=== Deploying DDLs ===")
    run_ddl("ddl-raw-accounts", SCRIPT_DIR, "ddl.raw_accounts.sql")
    run_ddl("ddl-raw-transactions", SCRIPT_DIR, "ddl.raw_transactions.sql")

    print("=== Running inserts ===")
    run_dml("insert-raw-accounts-1", SCRIPT_DIR, "insert_raw_accounts_1.sql", delete_after=True)
    run_dml("insert-raw-transactions-1", SCRIPT_DIR, "insert_raw_transactions_1.sql", delete_after=True)
    print("Done.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
