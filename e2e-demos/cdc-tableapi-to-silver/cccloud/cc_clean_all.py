#!/usr/bin/env python3
"""
Clean all tables and statements. 
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
_repo_root = Path(__file__).resolve().parent.parent.parent.parent
_flink_sql = _repo_root / "code" / "flink-sql"
if str(_flink_sql) not in sys.path:
    sys.path.insert(0, str(_flink_sql))

from tools.cc_flink_rest_client import  drop_table, delete_statement

def main() -> None:
    print("=== Cleaning all tables and statements ===")
    delete_statement("cdc-to-silver-table-job-api")
    drop_table("drop-tp-src-accounts", "tp_src_accounts")
    drop_table("drop-tp-src-transactions", "tp_src_transactions")
    drop_table("drop-tp-dim-accounts", "tp_dim_accounts")
    drop_table("drop-tp-fct-transactions", "tp_fct_transactions")
    drop_table("drop-raw-accounts", "raw_accounts")
    drop_table("drop-raw-transactions", "raw_transactions")
    print("Done.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
