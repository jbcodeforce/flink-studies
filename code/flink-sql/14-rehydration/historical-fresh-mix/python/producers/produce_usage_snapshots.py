#!/usr/bin/env python3
"""
Produce historical SaaS usage snapshots for historical-fresh-mix (topic: usage_snapshots).

Bulk load point-in-time usage totals before live events arrive.

Usage::

    cd python
    uv sync
    source ../../../../set_env.sh
    uv run producers/produce_usage_snapshots.py --count 150 --interval 0
"""

from __future__ import annotations

import argparse
import itertools
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel, Field

PRODUCTS = ("analytics-pro", "workflow-hub", "collab-suite")
FEATURES = ("api-calls", "exports", "dashboards")
SNAPSHOT_TS = "2025-06-01 00:00:00.000"


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

DEFAULT_TOPIC = "usage_snapshots"


class UsageSnapshot(BaseModel):
    """Value schema for usage-snapshots — date-time fields are ISO-8601 strings in JSON."""

    key: str
    product_id: str
    feature_id: str
    usage_count: int = Field(ge=0)
    snapshot_ts: str
    event_time: str


def _now_flink_ts() -> str:
    """UTC timestamp string for CAST(... AS TIMESTAMP_LTZ(3)): yyyy-MM-dd HH:mm:ss.SSS"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def _iter_combos(limit: int):
    combos = itertools.product(
        (f"user_{i:03d}" for i in range(1, 51)),
        PRODUCTS,
        FEATURES,
    )
    for idx, (key, product_id, feature_id) in enumerate(combos):
        if idx >= limit:
            break
        yield key, product_id, feature_id, idx


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce historical usage snapshots")
    parser.add_argument(
        "--count",
        "-c",
        type=int,
        default=150,
        help="Number of snapshot rows (max 450 = 50 users x 3 products x 3 features)",
    )
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.0)
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=not args.no_schema_registry,
        model_class=UsageSnapshot,
    )

    sent = 0
    for user_id, product_id, feature_id, idx in _iter_combos(args.count):
        record = UsageSnapshot(
            key=user_id,
            product_id=product_id,
            feature_id=feature_id,
            usage_count=10 + (idx % 90),
            snapshot_ts=SNAPSHOT_TS,
            event_time=_now_flink_ts(),
        )
        if not producer.send_record(record.key, record):
            print(f"Failed to send snapshot {sent + 1}/{args.count}")
            break
        sent += 1
        print(
            f"Queued {sent}/{args.count}: SNAPSHOT {record.key} "
            f"{record.product_id}/{record.feature_id} count={record.usage_count}"
        )
        if sent < args.count and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
