#!/usr/bin/env python3
"""
Produce SaaS usage events for classical-rehydration (topic: usage_events).

Aligns with cc/ddl.usage_events.sql. Includes duplicate event_id replays
to demonstrate dedup before aggregation.

Usage::

    cd python
    uv sync
    source ../../../../set_env.sh   # Confluent Cloud credentials
    uv run producers/produce_usage_events.py --count 30

    # Replay duplicates for the same event_id:
    uv run producers/produce_usage_events.py --count 10 --with-duplicates
"""

from __future__ import annotations

import argparse
import random
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel, Field

PRODUCTS = ("analytics-pro", "workflow-hub", "collab-suite")
FEATURES = ("api-calls", "exports", "dashboards")
USERS = tuple(f"user_{i:03d}" for i in range(1, 21))


def _flink_sql_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        lib = parent / "code" / "flink-sql" / "cm_py_lib" / "kafka_json_producer.py"
        if lib.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib. Run from the flink-studies repo."
    )


sys.path.insert(0, str(_flink_sql_root()))
from cm_py_lib.kafka_json_producer import KafkaJSONProducer  # noqa: E402

DEFAULT_TOPIC = "usage_events"


class UsageEvent(BaseModel):
    """Value schema for usage_events — event_time as yyyy-MM-dd HH:mm:ss.SSS for Flink CAST."""

    key: str
    product_id: str
    feature_id: str
    event_id: str
    usage_count: int = Field(ge=1)
    event_time: str


def _now_flink_ts() -> str:
    """UTC timestamp string for CAST(... AS TIMESTAMP_LTZ(3)): yyyy-MM-dd HH:mm:ss.SSS"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def generate_event(
    index: int,
    *,
    user_key: str | None = None,
    event_id: str | None = None,
) -> UsageEvent:
    return UsageEvent(
        key=user_key or random.choice(USERS),
        product_id=random.choice(PRODUCTS),
        feature_id=random.choice(FEATURES),
        event_id=event_id or f"evt-{uuid.uuid4().hex[:12]}",
        usage_count=random.randint(1, 50),
        event_time=_now_flink_ts(),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce SaaS usage events")
    parser.add_argument("--count", "-c", type=int, default=20)
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.3)
    parser.add_argument(
        "--with-duplicates",
        action="store_true",
        help="Replay ~30%% of events with the same event_id (lower usage_count)",
    )
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=not args.no_schema_registry,
        model_class=UsageEvent,
    )

    sent_ids: list[str] = []

    for i in range(args.count):
        replay_id = None
        if args.with_duplicates and sent_ids and i % 3 == 0:
            replay_id = random.choice(sent_ids)
        record = generate_event(i, event_id=replay_id)
        if replay_id is None:
            sent_ids.append(record.event_id)

        if not producer.send_record(record.key, record):
            print(f"Failed to send record {i + 1}/{args.count}")
            break
        print(
            f"Queued {i + 1}/{args.count}: {record.key} "
            f"{record.product_id}/{record.feature_id} count={record.usage_count} "
            f"id={record.event_id}"
        )
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
