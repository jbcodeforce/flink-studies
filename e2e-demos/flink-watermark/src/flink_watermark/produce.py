"""Load Kafka with a two-phase workload: all partitions to t=20s, then only partitions 0 and 1 to t=60s."""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from typing import Any

from confluent_kafka import Producer

from flink_watermark.schedule import (
    BASE_UTC,
    default_plan,
    event_time_at_offset,
    format_event_time_iso,
)

log = logging.getLogger(__name__)


def _build_payload(event_id: str, ts_iso: str) -> bytes:
    row: dict[str, Any] = {"event_id": event_id, "event_time": ts_iso}
    return json.dumps(row, separators=(",", ":")).encode("utf-8")


def _delivery_callback(err, _msg) -> None:
    if err is not None:
        log.warning("Delivery failed: %s", err)


def run(
    bootstrap: str,
    topic: str,
    dry_run: bool = False,
) -> None:
    plan = default_plan()
    pending = 0
    produced = 0

    producer: Producer | None = None
    if not dry_run:
        producer = Producer(
            {
                "bootstrap.servers": bootstrap,
                "enable.idempotence": False,
                "linger.ms": 0,
            }
        )

    def send(partition: int, t_sec: int) -> None:
        nonlocal pending, produced
        ev_t = event_time_at_offset(BASE_UTC, t_sec)
        ts = format_event_time_iso(ev_t)
        eid = f"p{partition}-t{t_sec:05d}"
        value = _build_payload(eid, ts)
        if dry_run:
            log.info("DRY p=%s t=%s", partition, t_sec)
            produced += 1
            return
        assert producer is not None
        producer.produce(
            topic,
            value=value,
            key=str(partition).encode("utf-8"),
            partition=partition,
            on_delivery=_delivery_callback,
        )
        pending += 1
        produced += 1
        if pending >= 10_000:
            producer.flush()
            pending = 0

    log.info(
        "Phase1: t=0..%s on partitions 0..%s",
        plan.phase1_end_inclusive_sec,
        plan.num_partitions - 1,
    )
    for t in range(0, plan.phase1_end_inclusive_sec + 1):
        for p in range(plan.num_partitions):
            send(p, t)
    if producer is not None:
        producer.flush()

    log.info(
        "Phase2: t=%s..%s on partitions %s only",
        plan.phase2_start_sec,
        plan.phase2_end_inclusive_sec,
        plan.active_partitions_phase2,
    )
    for t in range(plan.phase2_start_sec, plan.phase2_end_inclusive_sec + 1):
        for p in plan.active_partitions_phase2:
            send(p, t)

    if producer is not None:
        producer.flush()
    log.info("Done. Emitted %s events (see schedule.default_plan for expected counts).", produced)


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(levelname)s %(message)s",
    )
    p = argparse.ArgumentParser(description="Watermarks demo Kafka loader")
    p.add_argument(
        "--bootstrap",
        default=os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092"),
        help="Kafka bootstrap (host: port from the host, see docker-compose port mapping).",
    )
    p.add_argument(
        "--topic",
        default=os.environ.get("KAFKA_TOPIC", "watermark_demo"),
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not connect; print the phase plan only.",
    )
    args = p.parse_args()
    run(args.bootstrap, args.topic, dry_run=args.dry_run)
    sys.exit(0)


if __name__ == "__main__":
    main()
