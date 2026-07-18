#!/usr/bin/env python3
"""
Produce plain-JSON account lifecycle events (topic: raw_account_events).

No Schema Registry wire format — UTF-8 JSON only — so Flink can read the
payload via raw-value metadata and map it into the Avro-union account_events sink.

Usage::

    cd python
    uv sync
    source ../../set_env.sh
    uv run producers/produce_raw_account_events.py

    uv run producers/produce_raw_account_events.py --count 9 --interval 0.5
"""

from __future__ import annotations

import argparse
import time
import uuid
from typing import Any

from pydantic import BaseModel, Field

from _common import setup_cm_py_lib

setup_cm_py_lib()
from cm_py_lib.kafka_json_producer import KafkaJSONProducer  # noqa: E402

DEFAULT_TOPIC = "raw_account_events"


class EventContext(BaseModel):
    eventName: str
    correlationId: str
    sourceSystem: str


class RawAccountEvent(BaseModel):
    """Envelope matching the legacy JSON shape (contextInfo + varying eventDetail)."""

    contextInfo: EventContext
    eventDetail: dict[str, Any] = Field(default_factory=dict)


DEMO_EVENTS: tuple[dict[str, Any], ...] = (
    {
        "eventName": "DeviceSwap",
        "sourceSystem": "billing-system",
        "eventDetail": {"accountId": "acc-001", "deviceId": "dev-99"},
    },
    {
        "eventName": "Subscription",
        "sourceSystem": "billing-system",
        "eventDetail": {
            "accountId": "acc-002",
            "status": "ACTIVE",
            "planId": "plan-premium",
        },
    },
    {
        "eventName": "DeviceClose",
        "sourceSystem": "device-service",
        "eventDetail": {"accountId": "acc-003", "reasonCode": "CUSTOMER_REQUEST"},
    },
)


def _to_record(template: dict[str, Any], *, correlation_id: str | None = None) -> RawAccountEvent:
    correlation_id = correlation_id or f"corr-{uuid.uuid4().hex[:12]}"
    return RawAccountEvent(
        contextInfo=EventContext(
            eventName=template["eventName"],
            correlationId=correlation_id,
            sourceSystem=template["sourceSystem"],
        ),
        eventDetail=dict(template["eventDetail"]),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Produce raw_account_events plain JSON (no Schema Registry)"
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
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    # use_schema_registry=False: plain UTF-8 JSON bytes (honest raw_value demo).
    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=False,
    )

    for i in range(args.count):
        template = DEMO_EVENTS[i % len(DEMO_EVENTS)]
        record = _to_record(template)
        key = record.contextInfo.correlationId
        if not producer.send_record(key, record):
            print(f"Failed to send event {i + 1}/{args.count}")
            break
        print(
            f"Queued {i + 1}/{args.count}: {key} type={template['eventName']}"
        )
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
