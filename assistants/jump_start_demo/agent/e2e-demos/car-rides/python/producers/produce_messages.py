#!/usr/bin/env python3
"""
Produce sample driver customer ride trip_metrics daily_revenue records for car-rides (ride-sharing).

Uses ``cm_py_lib.kafka_json_producer.KafkaJSONProducer`` from
``code/flink-sql/cm_py_lib/``.

Usage::

    cd python
    uv sync
    uv run producers/produce_messages.py --count 10

    # Plain JSON without Schema Registry (local Kafka without SR):
    uv run producers/produce_messages.py --count 5 --no-schema-registry
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel


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

DEFAULT_TOPIC = os.getenv("KAFKA_TOPIC", "raw_rides")


class Driver customer ride tripMetrics dailyRevenueRecord(BaseModel):
    """Value schema for ``raw_rides`` — align with cccloud/ddl.driver customer ride trip_metrics daily_revenue.sql."""

    driver customer ride trip_metrics daily_revenue_id: str
    event_time: str
    payload: str = ""


def generate_record(index: int) -> Driver customer ride tripMetrics dailyRevenueRecord:
    return Driver customer ride tripMetrics dailyRevenueRecord(
        driver customer ride trip_metrics daily_revenue_id=f"car-rides-{uuid.uuid4().hex[:8]}",
        event_time=datetime.now(timezone.utc).isoformat(),
        payload=json.dumps(
            {"domain": "ride-sharing", "demo": "car-rides", "seq": index + 1}
        ),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce driver customer ride trip_metrics daily_revenue events for car-rides")
    parser.add_argument("--count", "-c", type=int, default=5)
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.5)
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    use_sr = not args.no_schema_registry
    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=use_sr,
        model_class=Driver customer ride tripMetrics dailyRevenueRecord,
    )

    for i in range(args.count):
        record = generate_record(i)
        if not producer.send_record(record.driver customer ride trip_metrics daily_revenue_id, record):
            print(f"Failed to send record {i + 1}/{args.count}")
            break
        print(f"Queued {i + 1}/{args.count}: {record.driver customer ride trip_metrics daily_revenue_id}")
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
