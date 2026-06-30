#!/usr/bin/env python3
"""
Produce generic envelope events (topic: event_stream).

Avro key: event_id. Avro value matches cc/ddl.event_stream.sql including
context_data (JSON string) and event_details (array of JSON payload strings).

Usage::

    cd python
    uv sync
    source ../../set_env.sh
    uv run producers/produce_event_stream.py

    uv run producers/produce_event_stream.py --count 20 --interval 0.5
"""

from __future__ import annotations

import argparse
import json
import time
import uuid

from _avro_common import detail_json, schemas_dir, setup_cm_py_lib, ts_millis

setup_cm_py_lib()
from cm_py_lib.kafka_avro_producer import KafkaAvroProducer  # noqa: E402

DEFAULT_TOPIC = "event_stream"

DEMO_EVENTS = (
    {
        "context_data": {"eventType": "subscription"},
        "event_details": [
            {
                "account_number": "acc-001",
                "plan_name": "Premium",
                "subscription_start": "2026-01-01T00:00:00.000Z",
            }
        ],
    },
    {
        "context_data": {"eventType": "deviceSwap"},
        "event_details": [
            {
                "account_number": "acc-002",
                "old_device_id": "device-old",
                "new_device_id": "device-new",
            }
        ],
    },
    {
        "context_data": {"eventType": "subscription"},
        "event_details": [
            {
                "account_number": "acc-010",
                "plan_name": "Family",
                "subscription_start": "2026-02-01T00:00:00.000Z",
            }
        ],
    },
)


def _to_record(template: dict, *, event_id: str | None = None) -> tuple[dict, dict]:
    event_id = event_id or f"evt-{uuid.uuid4().hex[:12]}"
    event_time = ts_millis()
    value = {
        "event_id": event_id,
        "event_time": event_time,
        "context_data": json.dumps(template["context_data"], separators=(",", ":")),
        "event_details": [detail_json(item) for item in template["event_details"]],
    }
    key = {"event_id": event_id}
    return key, value


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce event_stream Avro records")
    parser.add_argument(
        "--count",
        "-c",
        type=int,
        default=len(DEMO_EVENTS),
        help="Number of events (cycles through demo templates)",
    )
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.0)
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    schema_root = schemas_dir()
    producer = KafkaAvroProducer(
        topic_name=args.topic,
        key_schema_path=schema_root / "event_stream-key.avsc",
        value_schema_path=schema_root / "event_stream-value.avsc",
        use_schema_registry=not args.no_schema_registry,
    )

    for i in range(args.count):
        template = DEMO_EVENTS[i % len(DEMO_EVENTS)]
        key, value = _to_record(template)
        if not producer.send_record(key, value):
            print(f"Failed to send event {i + 1}/{args.count}")
            break
        event_type = template["context_data"]["eventType"]
        account = template["event_details"][0].get("account_number", "?")
        print(
            f"Queued {i + 1}/{args.count}: {value['event_id']} "
            f"type={event_type} account={account}"
        )
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
