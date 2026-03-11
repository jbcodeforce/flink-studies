#!/usr/bin/env python3
"""
Run validation SQL tests against Confluent Cloud Flink and print statement results.

Executes tests/validate_dim_account_1.sql and tests/validate_fct_transactions_1.sql
as snapshot queries, fetches the statement results, and prints them to the user.

Required env vars (same as cc_deploy_raw_data / cc_flink_rest_client):
  FLINK_API_KEY, FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY, CONFLUENT_CLOUD_API_SECRET)
  ORGANIZATION_ID, ENVIRONMENT_ID, COMPUTE_POOL_ID
  FLINK_BASE_URL or REGION + CLOUD

Run from the demo root with uv:
  uv run python cc_run_validate_tests.py
"""

import sys
from pathlib import Path

# Add code/flink-sql so we can import tools.cc_flink_rest_client
_repo_root = Path(__file__).resolve().parent.parent.parent.parent
_flink_sql = _repo_root / "code" / "flink-sql"
if str(_flink_sql) not in sys.path:
    sys.path.insert(0, str(_flink_sql))

from tools.cc_flink_rest_client import run_snapshot_query  # type: ignore[import-untyped]

TESTS_DIR = Path(__file__).resolve().parent / "tests"

VALIDATE_FILES = [
    ("fp-dim-accounts", "validate_dim_account_1.sql"),
    ("fp-fct-transactions", "validate_fct_transactions_1.sql"),
]


def main() -> None:
    print("=== Running validation tests ===\n")

    for statement_name, filename in VALIDATE_FILES:
        path = TESTS_DIR / filename
        if not path.exists():
            print(f"  Skip {filename}: file not found")
            continue
        sql = path.read_text().strip()
        # Remove SET line if present; run_snapshot_query already sets sql.snapshot.mode=now
        if sql.upper().startswith("SET "):
            first_newline = sql.find("\n")
            if first_newline != -1:
                sql = sql[first_newline + 1 :].strip()

        print(f"--- {filename} ---")
        try:
            rows = run_snapshot_query(f"validate-{statement_name}", sql)
            if rows:
                for i, row in enumerate(rows, 1):
                    # Row is typically [test_result, expected_count, pass_count]
                    print(f"  Row {i}: {row}")
                    if len(row) >= 1:
                        result = row[0] if isinstance(row[0], str) else str(row[0])
                        status = "PASS" if result.upper() == "PASS" else "FAIL"
                        print(f"  Test result: {status}")
            else:
                print("  (no rows returned)")
        except Exception as e:
            print(f"  Error: {e}")
        print()

    print("=== Done ===")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
