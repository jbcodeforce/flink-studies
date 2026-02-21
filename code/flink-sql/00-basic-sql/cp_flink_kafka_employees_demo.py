#!/usr/bin/env python3
"""
Deploy employee pipeline to Confluent Platform Flink (CMF) with Kafka topics/schemas.

Kafka topics and schemas for employees and employee_count are created via kubectl apply
(cp-flink/topics/*.yaml and cp-flink/schemas/*.yaml). DML (CTAS, inserts) and queries
run via CMF REST.

Prerequisites: CP Flink running in Kubernetes (see deployment/k8s/cmf), port-forward to
CMF REST (make port_forward_cmf or script can start it), environment and catalog created.

Config env: CMF_BASE_URL (default http://localhost:8084), CMF_ENV_NAME (dev-env),
CMF_COMPUTE_POOL_NAME (pool1), CMF_CATALOG_NAME (dev-catalog), CMF_DATABASE_NAME (kafka-db),
KUBECTL_NAMESPACE (confluent).
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

# Allow running from repo root, flink-sql, or 00-basic-sql (tools is under flink-sql)
_flink_sql_root = Path(__file__).resolve().parent.parent
if str(_flink_sql_root) not in sys.path:
    sys.path.insert(0, str(_flink_sql_root))

from tools import cp_flink_rest_client as cmf
from tools import cp_flink_utils

SCRIPT_DIR = Path(__file__).resolve().parent
FLINK_STATEMENT_TIMEOUT = 600
POLL_INTERVAL = 10
PF_TIMEOUT = 60

# Expected department counts from README (dept_id -> count)
EXPECTED_DEPT_COUNTS = {101: 5, 102: 6, 103: 4, 104: 1}


def _base_url() -> str:
    return (os.environ.get("CMF_BASE_URL") or "http://localhost:8084").rstrip("/")


def _env_name() -> str:
    return os.environ.get("CMF_ENV_NAME") or "dev-env"


def _catalog_name() -> str:
    return os.environ.get("CMF_CATALOG_NAME") or "dev-catalog"


def _database_name() -> str:
    return os.environ.get("CMF_DATABASE_NAME") or "kafka-db"


def _compute_pool_name() -> str:
    return os.environ.get("CMF_COMPUTE_POOL_NAME") or "pool1"


def preflight(skip_kubectl: bool, no_port_forward: bool) -> str:
    base_url = _base_url()
    if not skip_kubectl:
        cp_flink_utils.check_pods(False)
    cmf.ensure_cmf_reachable(start_port_forward=not no_port_forward, base_url=base_url)
    env_name = _env_name()
    cmf.check_environment(env_name, base_url=base_url)
    cmf.check_catalog(_catalog_name(), base_url=base_url)
    cmf.check_compute_pool(env_name, _compute_pool_name(), base_url=base_url)
    return base_url


CP_FLINK_DIR = SCRIPT_DIR / "cp-flink"

# Order matters: ConfigMaps (schema content) first, then Schemas (reference ConfigMaps), then Topics.
KAFKA_TABLE_YAMLS = [
    "schemas/employees_value_cm.yaml",
    "schemas/employee_count_value_cm.yaml",
    "schemas/employees_value_schema.yaml",
    "schemas/employee_count_value_schema.yaml",
    "topics/employees_topic.yaml",
    "topics/employee_count_topic.yaml",
]


def create_kafka_database_tables(base_url: str) -> None:
    """Create Kafka topics and schemas for employees and employee_count via kubectl apply."""
    ns = cp_flink_utils.kubectl_ns()
    for rel in KAFKA_TABLE_YAMLS:
        path = CP_FLINK_DIR / rel
        if not path.exists():
            raise FileNotFoundError(path)
        print(f"Applying: {rel}")
        out = subprocess.run(
            ["kubectl", "apply", "-f", str(path), "-n", ns],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if out.returncode != 0:
            raise RuntimeError(f"kubectl apply -f {path} failed: {out.stderr or out.stdout}")
        print(f"  Done: {rel}")
    print("Kafka database tables (topics + schemas) created.")


def run_dml(base_url: str, name: str, sql_file: str, delete_after: bool = True) -> None:
    path = SCRIPT_DIR / sql_file
    if not path.exists():
        raise FileNotFoundError(path)
    sql = path.read_text()
    env_name = _env_name()
    print(f"Running DML: {path.name} (statement: {name})")
    try:
        cmf.create_statement(
            env_name,
            name,
            sql,
            base_url=base_url,
            wait_phase=["RUNNING", "COMPLETED"],
            poll_interval=POLL_INTERVAL,
            timeout=FLINK_STATEMENT_TIMEOUT,
        )
    except Exception as e:
        print(f"Error running DML: {e}")
        raise
    finally:
            cmf.delete_statement(env_name, name, base_url=base_url)


def run_snapshot_query(base_url: str, name: str, query: str) -> list:
    env_name = _env_name()
    print(f"Running snapshot query: {name}")
    cmf.create_statement(
        env_name,
        name,
        query,
        base_url=base_url,
        properties={"sql.snapshot.mode": "now"},
        wait_phase="COMPLETED",
        poll_interval=POLL_INTERVAL,
        timeout=FLINK_STATEMENT_TIMEOUT,
    )
    try:
        out = cmf.get_statement_results(env_name, name, base_url=base_url, timeout=120)
        rows = out.get("results") or []
        print(f"----------\nSnapshot query results: {len(rows)} rows\n----------")
        return rows
    finally:
        cmf.delete_statement(env_name, name, base_url=base_url)


def run_query_no_results(base_url: str, name: str, query: str) -> None:
    env_name = _env_name()
    print(f"Running query: {name}")
    cmf.create_statement(
        env_name,
        name,
        query,
        base_url=base_url,
        wait_phase="COMPLETED",
        poll_interval=POLL_INTERVAL,
        timeout=FLINK_STATEMENT_TIMEOUT,
    )
    cmf.delete_statement(env_name, name, base_url=base_url)
    print(f"  Done: {name}")


def assert_dept_counts(rows: list) -> None:
    # rows: list of [dept_id, emp_count] (or similar)
    by_dept = {}
    for r in rows:
        if not r:
            continue
        if len(r) >= 2:
            dept_id = int(r[0]) if isinstance(r[0], (int, float)) else int(r[0])
            count = int(r[1]) if isinstance(r[1], (int, float)) else int(r[1])
            by_dept[dept_id] = count
        elif len(r) == 1:
            by_dept[int(r[0])] = 1
    for dept_id, expected in EXPECTED_DEPT_COUNTS.items():
        actual = by_dept.get(dept_id)
        if actual != expected:
            raise AssertionError(
                f"Department {dept_id}: expected count {expected}, got {actual}. "
                f"All rows: {by_dept}"
            )
    print("Validation OK: department counts match expected (101->5, 102->6, 103->4, 104->1)")


def run_delete_only(base_url: str) -> None:
    env_name = _env_name()
    for st in ("employee-count", "insert-employees", "snapshot-query"):
        try:
            cmf.delete_statement(env_name, st, base_url=base_url)
        except Exception as e:
            print(f"  (skip {st}: {e})")
    run_query_no_results(base_url, "drop-employee-count", "DROP TABLE IF EXISTS employee_count;")
    run_query_no_results(base_url, "drop-employees", "DROP TABLE IF EXISTS employees;")
    print("Cleanup done")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deploy employee SQLs to Confluent Platform Flink (CMF) and validate end-to-end.",
    )
    parser.add_argument(
        "--skip-kubectl",
        action="store_true",
        help="Skip kubectl get pods check (e.g. when port-forward is from another machine).",
    )
    parser.add_argument(
        "--no-port-forward",
        action="store_true",
        help="Do not start port-forward; fail if CMF is unreachable.",
    )
    parser.add_argument(
        "--delete-only",
        action="store_true",
        help="Only cleanup statements and tables.",
    )
    parser.add_argument(
        "--ddl-only",
        action="store_true",
        help="Only create Kafka topics and schemas (kubectl apply cp-flink YAMLs).",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only run snapshot query and assert counts (tables must exist).",
    )
    args = parser.parse_args()

    base_url = _base_url()
    if not args.delete_only:
        base_url = preflight(args.skip_kubectl, args.no_port_forward)

    if args.delete_only:
        print("=== Cleanup ===")
        run_delete_only(base_url)
        return

    if args.validate_only:
        print("=== Validate only (snapshot query) ===")
        rows = run_snapshot_query(
            base_url,
            "snapshot-query",
            "SELECT * FROM employee_count;",
        )
        assert_dept_counts(rows)
        return

    if args.ddl_only:
        print("=== Creating Kafka database tables ===")
        create_kafka_database_tables(base_url)
        return

    # Full flow
    print("=== Creating Kafka database tables ===")
    create_kafka_database_tables(base_url)
    print("=== Running employee_count ===")
    run_dml(base_url, "employee-count", "cp-flink/dml.employee_count.sql", delete_after=False)
    print("=== Running snapshot query ===")
    rows = run_snapshot_query(
        base_url,
        "snapshot-query",
        "SELECT * FROM employee_count;",
    )
    assert_dept_counts(rows)
    if rows:
        print("Snapshot results (employee_count):")
        for i, row in enumerate(rows, 1):
            print(f"  {i}: {row}")
    print("Done.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
