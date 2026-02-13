#!/usr/bin/env python3
"""
Deploy or undeploy Flink SQL statements for the compute_eta demo using the Confluent CLI.

Usage:
  python deploy_flink_statements.py deploy [--confluent-cloud]
  python deploy_flink_statements.py undeploy

Requires: Confluent CLI installed and logged in. Set env vars:
  ENV_ID or CCLOUD_ENV_ID
  COMPUTE_POOL_ID or CPOOLID or CCLOUD_COMPUTE_POOL_ID
  DB_NAME or CCLOUD_KAFKA_CLUSTER
  CC_CONTEXT or CCLOUD_CONTEXT
  CLOUD, REGION (for undeploy)
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Statement names and SQL files in deployment order (default: filesystem DDL)
SCRIPT_DIR = Path(__file__).resolve().parent

STATEMENTS_DEFAULT = [
    ("compute-eta-ddl-shipment-events", "ddl.shipments_table.sql"),
    ("compute-eta-ddl-shipment-history", "ddl.shipment_history.sql"),
    ("compute-eta-dml-shipment-history", "dml.shipment_history.sql"),
    ("compute-eta-dml-compute-eta", "dml.compute_eta.sql"),
]

# Confluent Cloud: use DDL from confluent/ subfolder (Kafka-backed tables)
CONFLUENT_DDL_FILES = [
    ("compute-eta-ddl-shipment-events", "confluent/ddl.shipments_table.sql"),
    ("compute-eta-ddl-shipment-history", "confluent/ddl.shipment_history.sql"),
]
# DML files are the same for both modes
CONFLUENT_DML_FILES = [
    ("compute-eta-dml-shipment-history", "dml.shipment_history.sql"),
    ("compute-eta-dml-compute-eta", "dml.compute_eta.sql"),
]


def get_config() -> dict[str, str]:
    """Read Confluent context from environment."""
    env_id = os.environ.get("CCLOUD_ENV_ID") or os.environ.get("ENV_ID")
    pool_id = (
        os.environ.get("CCLOUD_COMPUTE_POOL_ID")
        or os.environ.get("COMPUTE_POOL_ID")
        or os.environ.get("CPOOLID")
    )
    db_name = os.environ.get("CCLOUD_KAFKA_CLUSTER") or os.environ.get("DB_NAME")
    context = os.environ.get("CCLOUD_CONTEXT") or os.environ.get("CC_CONTEXT")
    cloud = os.environ.get("CLOUD_PROVIDER") or os.environ.get("CLOUD", "aws")
    region = os.environ.get("CLOUD_REGION") or os.environ.get("REGION", "us-west-2")

    missing = []
    if not env_id:
        missing.append("ENV_ID or CCLOUD_ENV_ID")
    if not pool_id:
        missing.append("COMPUTE_POOL_ID/CPOOLID or CCLOUD_COMPUTE_POOL_ID")
    if not db_name:
        missing.append("DB_NAME or CCLOUD_KAFKA_CLUSTER")
    if not context:
        missing.append("CC_CONTEXT or CCLOUD_CONTEXT")

    if missing:
        print("Missing required environment variables:", ", ".join(missing), file=sys.stderr)
        print(
            "Set ENV_ID, COMPUTE_POOL_ID (or CPOOLID), DB_NAME, CC_CONTEXT (or CCLOUD_* variants).",
            file=sys.stderr,
        )
        sys.exit(1)

    return {
        "ENV_ID": env_id,
        "COMPUTE_POOL_ID": pool_id,
        "DB_NAME": db_name,
        "CC_CONTEXT": context,
        "CLOUD": cloud,
        "REGION": region,
    }


def read_sql(path: Path) -> str:
    """Read SQL file content."""
    if not path.exists():
        raise FileNotFoundError(f"SQL file not found: {path}")
    return path.read_text().strip()


def get_statements(confluent_cloud: bool) -> list[tuple[str, Path]]:
    """Return list of (statement_name, sql_file_path) in deployment order."""
    if confluent_cloud:
        out = []
        for name, rel in CONFLUENT_DDL_FILES + CONFLUENT_DML_FILES:
            out.append((name, SCRIPT_DIR / rel))
        return out
    return [(name, SCRIPT_DIR / rel) for name, rel in STATEMENTS_DEFAULT]


def run_create(name: str, sql_content: str, config: dict[str, str]) -> None:
    """Run confluent flink statement create."""
    cmd = [
        "confluent",
        "flink",
        "statement",
        "create",
        name,
        "--sql",
        sql_content,
        "--database",
        config["DB_NAME"],
        "--compute-pool",
        config["COMPUTE_POOL_ID"],
        "--environment",
        config["ENV_ID"],
        "--context",
        config["CC_CONTEXT"],
        "--wait",
    ]
    print(f"Creating statement: {name}")
    subprocess.run(cmd, check=True)


def run_delete(name: str, config: dict[str, str]) -> None:
    """Run confluent flink statement delete."""
    cmd = [
        "confluent",
        "flink",
        "statement",
        "delete",
        name,
        "--cloud",
        config["CLOUD"],
        "--region",
        config["REGION"],
        "--context",
        config["CC_CONTEXT"],
        "--environment",
        config["ENV_ID"],
    ]
    print(f"Deleting statement: {name}")
    subprocess.run(cmd, check=True)


def deploy(confluent_cloud: bool) -> None:
    """Deploy all statements in order."""
    config = get_config()
    statements = get_statements(confluent_cloud)
    for name, sql_path in statements:
        sql_content = read_sql(sql_path)
        run_create(name, sql_content, config)
    print("Deploy complete.")


def undeploy(confluent_cloud: bool) -> None:
    """Undeploy all statements in reverse order."""
    config = get_config()
    statements = get_statements(confluent_cloud)
    for name, _ in reversed(statements):
        run_delete(name, config)
    print("Undeploy complete.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deploy or undeploy compute_eta Flink statements via Confluent CLI."
    )
    parser.add_argument(
        "action",
        choices=["deploy", "undeploy"],
        help="Deploy or undeploy Flink statements",
    )
    parser.add_argument(
        "--confluent-cloud",
        action="store_true",
        help="Use Confluent Cloud DDL (Kafka-backed tables) from confluent/ folder",
    )
    args = parser.parse_args()

    if args.action == "deploy":
        deploy(args.confluent_cloud)
    else:
        undeploy(args.confluent_cloud)


if __name__ == "__main__":
    main()
