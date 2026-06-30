#!/usr/bin/env python3
"""
Produce party-to-account reference rows (topic: party_info).

Avro key: party_id + account_number (matches cc/ddl.party_info.sql PRIMARY KEY).
Avro value: full party_info row.

Usage::

    cd python
    uv sync
    source ../../set_env.sh
    uv run producers/produce_party_info.py
"""

from __future__ import annotations

import argparse

from _avro_common import schemas_dir, setup_cm_py_lib, ts_millis

setup_cm_py_lib()
from cm_py_lib.kafka_avro_producer import KafkaAvroProducer  # noqa: E402

DEFAULT_TOPIC = "party_info"

PARTY_ROWS = (
    {
        "party_id": "party-100",
        "account_number": "acc-001",
        "plan_name": "Premium",
        "subscription_start": "2026-01-01T00:00:00.000Z",
        "addr_street": "123 Main St",
        "addr_city": "Austin",
        "addr_state": "TX",
        "addr_zip": "78701",
    },
    {
        "party_id": "party-100",
        "account_number": "acc-002",
        "plan_name": "Premium",
        "subscription_start": "2026-01-01T00:00:00.000Z",
        "addr_street": "123 Main St",
        "addr_city": "Austin",
        "addr_state": "TX",
        "addr_zip": "78701",
    },
    {
        "party_id": "party-200",
        "account_number": "acc-010",
        "plan_name": "Family",
        "subscription_start": "2026-02-01T00:00:00.000Z",
        "addr_street": "456 Oak Ave",
        "addr_city": "Denver",
        "addr_state": "CO",
        "addr_zip": "80202",
    },
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce party_info Avro records")
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    schema_root = schemas_dir()
    producer = KafkaAvroProducer(
        topic_name=args.topic,
        key_schema_path=schema_root / "party_info-key.avsc",
        value_schema_path=schema_root / "party_info-value.avsc",
        use_schema_registry=not args.no_schema_registry,
    )

    updated_at = ts_millis()
    for row in PARTY_ROWS:
        value = {
            **row,
            "subscription_start": ts_millis(row["subscription_start"]),
            "updated_at": updated_at,
        }
        key = {
            "party_id": row["party_id"],
            "account_number": row["account_number"],
        }
        if not producer.send_record(key, value):
            print(f"Failed to send {row['party_id']}/{row['account_number']}")
            break
        print(
            f"Queued {row['party_id']} -> {row['account_number']} "
            f"({row['plan_name']})"
        )

    producer.flush_and_close()


if __name__ == "__main__":
    main()
