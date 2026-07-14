#!/usr/bin/env python3
"""
Produce account lifecycle events with an Avro union eventDetail
(topic: account_events).

Avro key: correlationId. Avro value: AccountLifecycleEvent with contextInfo
and eventDetail as DeviceSwapDetail | SubscriptionDetail | DeviceCloseDetail.

Usage::

    cd python
    uv sync
    source ../../set_env.sh
    uv run producers/produce_account_events.py

    uv run producers/produce_account_events.py --count 9 --interval 0.5
"""

from __future__ import annotations

import argparse
import time
import uuid

from _avro_common import schemas_dir, setup_cm_py_lib

setup_cm_py_lib()
from cm_py_lib.kafka_avro_producer import KafkaAvroProducer  # noqa: E402

DEFAULT_TOPIC = "account_events"
NS = "io.confluent.flink.multievent"

# fastavro / Confluent AvroSerializer: tag ambiguous unions with (fullName, record).
DEMO_EVENTS = (
    {
        "eventName": "DeviceSwap",
        "sourceSystem": "billing-system",
        "eventDetail": (
            f"{NS}.DeviceSwapDetail",
            {"accountId": "acc-001", "deviceId": "dev-99"},
        ),
    },
    {
        "eventName": "Subscription",
        "sourceSystem": "billing-system",
        "eventDetail": (
            f"{NS}.SubscriptionDetail",
            {
                "accountId": "acc-002",
                "status": "ACTIVE",
                "planId": "plan-premium",
            },
        ),
    },
    {
        "eventName": "DeviceClose",
        "sourceSystem": "device-service",
        "eventDetail": (
            f"{NS}.DeviceCloseDetail",
            {"accountId": "acc-003", "reasonCode": "CUSTOMER_REQUEST"},
        ),
    },
)


def _to_record(template: dict, *, correlation_id: str | None = None) -> tuple[dict, dict]:
    correlation_id = correlation_id or f"corr-{uuid.uuid4().hex[:12]}"
    value = {
        "contextInfo": {
            "eventName": template["eventName"],
            "correlationId": correlation_id,
            "sourceSystem": template["sourceSystem"],
        },
        "eventDetail": template["eventDetail"],
    }
    key = {"correlationId": correlation_id}
    return key, value


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Produce account_events Avro records (union eventDetail)"
    )
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
        key_schema_path=schema_root / "account_events-key.avsc",
        value_schema_path=schema_root / "account_events-value.avsc",
        value_schema_references=[
            schema_root / "DeviceSwapDetail.avsc",
            schema_root / "SubscriptionDetail.avsc",
            schema_root / "DeviceCloseDetail.avsc",
        ],
        use_schema_registry=not args.no_schema_registry,
    )

    for i in range(args.count):
        template = DEMO_EVENTS[i % len(DEMO_EVENTS)]
        key, value = _to_record(template)
        if not producer.send_record(key, value):
            print(f"Failed to send event {i + 1}/{args.count}")
            break
        print(
            f"Queued {i + 1}/{args.count}: {key['correlationId']} "
            f"type={template['eventName']}"
        )
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
