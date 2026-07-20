#!/usr/bin/env python3
"""
Produce multi-schema JSON account lifecycle events (topic: raw_account_events).

Registers three incompatible JSON Schema versions under a single TopicNameStrategy
subject ``raw_account_events-value`` (compatibility NONE) and produces Confluent
wire-format payloads pinned with ``use.schema.id`` per event type. Flink reads via
raw-value, strips the 5-byte prefix, and maps into the Avro-union account_events sink.

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
from typing import Any, Type

from pydantic import BaseModel, ConfigDict

from _common import setup_cm_py_lib

setup_cm_py_lib()
from multi_schema_json_producer import MultiSchemaJsonProducer  # noqa: E402

DEFAULT_TOPIC = "raw_account_events"
NS = "io.confluent.flink.multievent"


class EventContext(BaseModel):
    eventName: str
    correlationId: str
    sourceSystem: str


class DeviceSwapDetail(BaseModel):
    accountId: str
    deviceId: str


class SubscriptionDetail(BaseModel):
    accountId: str
    status: str
    planId: str


class DeviceCloseDetail(BaseModel):
    accountId: str
    reasonCode: str


class DeviceSwapEvent(BaseModel):
    """Title is for SR UI readability only — subject is TopicNameStrategy."""

    model_config = ConfigDict(title=f"{NS}.DeviceSwapEvent")

    contextInfo: EventContext
    eventDetail: DeviceSwapDetail


class SubscriptionEvent(BaseModel):
    model_config = ConfigDict(title=f"{NS}.SubscriptionEvent")

    contextInfo: EventContext
    eventDetail: SubscriptionDetail


class DeviceCloseEvent(BaseModel):
    model_config = ConfigDict(title=f"{NS}.DeviceCloseEvent")

    contextInfo: EventContext
    eventDetail: DeviceCloseDetail


EVENT_MODELS: list[Type[BaseModel]] = [
    DeviceSwapEvent,
    SubscriptionEvent,
    DeviceCloseEvent,
]

DEMO_BUILDERS: tuple[tuple[str, Any], ...] = (
    (
        "DeviceSwap",
        lambda corr: DeviceSwapEvent(
            contextInfo=EventContext(
                eventName="DeviceSwap",
                correlationId=corr,
                sourceSystem="billing-system",
            ),
            eventDetail=DeviceSwapDetail(accountId="acc-001", deviceId="dev-99"),
        ),
    ),
    (
        "Subscription",
        lambda corr: SubscriptionEvent(
            contextInfo=EventContext(
                eventName="Subscription",
                correlationId=corr,
                sourceSystem="billing-system",
            ),
            eventDetail=SubscriptionDetail(
                accountId="acc-002",
                status="ACTIVE",
                planId="plan-premium",
            ),
        ),
    ),
    (
        "DeviceClose",
        lambda corr: DeviceCloseEvent(
            contextInfo=EventContext(
                eventName="DeviceClose",
                correlationId=corr,
                sourceSystem="device-service",
            ),
            eventDetail=DeviceCloseDetail(
                accountId="acc-003",
                reasonCode="CUSTOMER_REQUEST",
            ),
        ),
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Produce raw_account_events with three JSON schemas on one "
            "TopicNameStrategy subject (compatibility NONE, pinned schema ids)"
        )
    )
    parser.add_argument(
        "--count",
        "-c",
        type=int,
        default=len(DEMO_BUILDERS),
        help="Number of events (cycles through demo templates)",
    )
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    producer = MultiSchemaJsonProducer(
        topic_name=args.topic,
        model_classes=EVENT_MODELS,
    )
    print(f"Schema Registry subject: {producer.subject_name}")
    print("Pinned schema ids (TopicNameStrategy + NONE):")
    for name, schema_id in producer.schema_ids().items():
        print(f"  {name} -> schema_id={schema_id}")

    for i in range(args.count):
        event_name, builder = DEMO_BUILDERS[i % len(DEMO_BUILDERS)]
        corr = f"corr-{uuid.uuid4().hex[:12]}"
        record = builder(corr)
        if not producer.send_record(corr, record):
            print(f"Failed to send event {i + 1}/{args.count}")
            break
        print(f"Queued {i + 1}/{args.count}: {corr} type={event_name}")
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
