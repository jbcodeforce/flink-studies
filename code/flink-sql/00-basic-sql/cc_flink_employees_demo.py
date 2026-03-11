#!/usr/bin/env python3
"""
Deploy DDL and insert statements to Confluent Cloud Flink using the REST API.

Run from this directory. No Confluent CLI required.

Required env vars:
  FLINK_API_KEY, FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY, CONFLUENT_CLOUD_API_SECRET)
  ORGANIZATION_ID, ENVIRONMENT_ID, COMPUTE_POOL_ID
  FLINK_BASE_URL (e.g. https://flink.us-west-2.aws.confluent.cloud)
    or REGION + CLOUD (e.g. us-west-2, aws)

Optional: DB_NAME (default j9r-kafka), CATALOG_NAME.
"""

import argparse
import sys
from pathlib import Path

# Allow running from repo root, flink-sql, or 00-basic-sql (tools is under flink-sql)
_flink_sql_root = Path(__file__).resolve().parent.parent
if str(_flink_sql_root) not in sys.path:
    sys.path.insert(0, str(_flink_sql_root))

from tools.cc_flink_rest_client import (
    create_statement,
    delete_statement,
    get_statement_results,
    run_ddl,
    run_dml,
    run_snapshot_query,
    run_query_no_results,
)


SCRIPT_DIR = Path(__file__).resolve().parent



def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deploy DDL and insert statements to Confluent Cloud Flink via REST API.",
    )
    parser.add_argument(
        "--ddl-only",
        action="store_true",
        help="Deploy only DDL (employees table).",
    )
    parser.add_argument(
        "--insert-only",
        action="store_true",
        help="Run only insert statements (requires DDL already deployed).",
    )
    parser.add_argument(
        "--delete-only",
        action="store_true",
        help="Drop tables and delete statements.",
    )
    parser.add_argument(
        "--employee-count-only",
        action="store_true",
        help="Run only employee_count statements.",
    )
    parser.add_argument(
        "--snapshot-query-only",
        action="store_true",
        help="Run only snapshot query statements.",
    )
    args = parser.parse_args()

    if args.snapshot_query_only:
        print("=== Running snapshot query ===")
        rows = run_snapshot_query(
            "snapshot-query",
            "SELECT * FROM employee_count;",
        )
        print("Done.")
        return

    if args.employee_count_only:
        print("=== Running employee_count ===")
        run_dml("employee-count", SCRIPT_DIR, "dml.employee_count.sql", delete_after=False)
        print("Done.")
        return

    if args.ddl_only:
        print("=== Deploying DDL ===")
        run_ddl("ddl-employees", SCRIPT_DIR, "ddl.employee.sql")
        print("Done.")
        return

    if args.insert_only:
        print("=== Running inserts ===")
        run_dml("insert-employees", SCRIPT_DIR, "insert_employees.sql", delete_after=True)
        print("Done.")
        return

    if args.delete_only:
        print("=== Deleting tables and statements ===")
        for st in ("employee-count", "insert-employees", "snapshot-query"):
            try:
                delete_statement(st)
            except Exception as e:
                print(f"  (skip {st}: {e})")
        run_query_no_results("drop-employee-count", "DROP TABLE IF EXISTS employee_count;")
        run_query_no_results("drop-employees", "DROP TABLE IF EXISTS employees;")
        print("Done.")
        return

    # Full flow: DDL -> insert -> CTAS -> snapshot query (with results)
    print("=== Deploying DDL ===")
    run_ddl("ddl-employees", SCRIPT_DIR, "ddl.employee.sql")

    print("=== Running inserts ===")
    run_dml("insert-employees", SCRIPT_DIR, "insert_employees.sql", delete_after=True)

    print("=== Running CTAS employee_count ===")
    run_dml("employee-count", SCRIPT_DIR, "dml.employee_count.sql", delete_after=False)

    print("=== Running snapshot query ===")
    rows = run_snapshot_query(
        "snapshot-query",
        "SELECT * FROM employee_count;",
    )
    if rows:
        print("Snapshot query results (employee_count):")
        for i, row in enumerate(rows, 1):
            print(f"  {i}: {row}")
    else:
        print("  (no rows)")
    print("Done.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
