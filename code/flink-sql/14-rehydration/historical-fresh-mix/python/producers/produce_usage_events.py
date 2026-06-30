#!/usr/bin/env python3
"""
Produce live SaaS usage events for historical-fresh-mix (topic: usage-events).

Targets a subset of users that also appear in snapshot data so live rows
override snapshot totals in unified_user_usage.

Usage::

    cd python
    uv sync
    source ../../../../set_env.sh
    uv run producers/produce_usage_events.py --count 15
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

# Overlap with produce_usage_snapshots.py user keys
LIVE_USERS = ("user_001", "user_002", "user_003", "user_004", "user_005")
PRODUCTS = ("analytics-pro", "workflow-hub")
FEATURES = ("api-calls", "exports", "dashboards")


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
    key: str
    product_id: str
    feature_id: str
    event_id: str
    usage_count: int = Field(ge=1)
    event_time: str


def _now_flink_ts() -> str:
    """UTC timestamp string for CAST(... AS TIMESTAMP_LTZ(3)): yyyy-MM-dd HH:mm:ss.SSS"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def generate_event(index: int) -> UsageEvent:
    user = LIVE_USERS[index % len(LIVE_USERS)]
    product = PRODUCTS[index % len(PRODUCTS)]
    feature = FEATURES[index % len(FEATURES)]
    return UsageEvent(
        key=user,
        product_id=product,
        feature_id=feature,
        event_id=f"live-{uuid.uuid4().hex[:12]}",
        usage_count=random.randint(100, 500),
        event_time=_now_flink_ts(),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce live SaaS usage events")
    parser.add_argument("--count", "-c", type=int, default=15)
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.5)
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

    for i in range(args.count):
        record = generate_event(i)
        if not producer.send_record(record.key, record):
            print(f"Failed to send record {i + 1}/{args.count}")
            break
        print(
            f"Queued {i + 1}/{args.count}: LIVE {record.key} "
            f"{record.product_id}/{record.feature_id} count={record.usage_count}"
        )
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
