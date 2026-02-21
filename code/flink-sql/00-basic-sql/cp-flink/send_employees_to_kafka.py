#!/usr/bin/env python3
"""
Send employee records from data/employees.csv to the Kafka topic "employees".

Kafka must be reachable from the host via port-forward.

- Kraft cluster (deployment/k8s/cfk/kraft-cluster.yaml): broker listens on 9092.
  Forward the same port: kubectl port-forward svc/kafka 9092:9092 -n confluent
  Use bootstrap localhost:9092 (default).

- CFK kafka-cluster with EXTERNAL listener on 9094: port-forward 9094:9094 and
  set KAFKA_BOOTSTRAP_SERVERS=localhost:9094.

If port-forward fails with "Connection refused", the service port may not match
the pod listener; run kubectl get svc kafka -n confluent and forward to the
port the pod actually listens on (e.g. 9071 -> use 9092:9071 and localhost:9092).
"""

import argparse
import csv
import json
import os
import sys
from pathlib import Path

from confluent_kafka import Producer

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CSV = SCRIPT_DIR / ".." / "data" / "employees.csv"


def _bootstrap_servers() -> str:
    return os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")


def load_employees(csv_path: Path) -> list[dict]:
    """Read CSV (no header): emp_id, name, dept_id. Return list of dicts."""
    rows = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.reader(f):
            if len(row) < 3:
                continue
            emp_id_s, name, dept_id_s = row[0].strip(), row[1].strip(), row[2].strip()
            if not emp_id_s or not dept_id_s:
                continue
            try:
                emp_id = int(emp_id_s)
                dept_id = int(dept_id_s)
            except ValueError:
                continue
            rows.append({"emp_id": emp_id, "name": name, "dept_id": dept_id})
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Send employee records from CSV to the employees Kafka topic.",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Path to employees CSV (default: {DEFAULT_CSV})",
    )
    parser.add_argument(
        "--topic",
        type=str,
        default="employees",
        help="Kafka topic name (default: employees)",
    )
    args = parser.parse_args()

    csv_path = args.csv.resolve()
    if not csv_path.exists():
        print(f"Error: CSV file not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    records = load_employees(csv_path)
    if not records:
        print("No valid employee records in CSV.", file=sys.stderr)
        sys.exit(1)

    conf = {"bootstrap.servers": _bootstrap_servers()}
    producer = Producer(conf)

    def delivery_cb(err, msg):
        if err:
            print(f"Delivery failed: {err}", file=sys.stderr)

    for r in records:
        key = str(r["emp_id"]).encode("utf-8")
        value = json.dumps(
            {"emp_id": r["emp_id"], "name": r["name"], "dept_id": r["dept_id"]}
        ).encode("utf-8")
        producer.produce(
            topic=args.topic,
            key=key,
            value=value,
            on_delivery=delivery_cb,
        )
        producer.poll(0)

    producer.flush()
    print(f"Sent {len(records)} employee records to topic {args.topic}.")


if __name__ == "__main__":
    main()
