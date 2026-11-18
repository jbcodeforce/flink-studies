"""Print the most recent messages of a topic (read-only), decoding Schema Registry JSON.

Why this exists: on the private DR cluster the Confluent Cloud message viewer does not work
("your browser must have access to your cluster's private endpoints"). Run this where the
Kafka endpoint resolves: the laptop for primary, the DR bastion for DR.

It never commits offsets and uses no consumer group state, so it is safe to run at any time,
including on mirror topics.

Environment (export-env.sh): KAFKA_BOOTSTRAP_SERVERS, KAFKA_API_KEY, KAFKA_API_SECRET

Usage:
  uv run python peek_topic.py rides_raw                 # last 10 messages
  uv run python peek_topic.py rides_clean --last 25
  uv run python peek_topic.py driver_stats --partition 3 --last 5
  uv run python peek_topic.py rides_raw --follow        # keep printing new messages
  uv run python peek_topic.py rides_raw --stats         # offsets per partition only
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

from confluent_kafka import Consumer, KafkaError, TopicPartition


def _decode(raw: bytes | None) -> tuple[int | None, object]:
    """Return (schema_id, value). Handles SR wire format (magic 0 + 4-byte id) and plain JSON."""
    if raw is None:
        return None, None
    schema_id = None
    body = raw
    if len(raw) > 5 and raw[0] == 0:
        schema_id = int.from_bytes(raw[1:5], "big")
        body = raw[5:]
    try:
        return schema_id, json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return schema_id, f"<{len(body)} bytes, not JSON: {body[:32].hex()}>"


def _consumer() -> Consumer:
    bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    key = os.environ.get("KAFKA_API_KEY")
    secret = os.environ.get("KAFKA_API_SECRET")
    if not (bootstrap and key and secret):
        raise SystemExit("Set KAFKA_BOOTSTRAP_SERVERS / KAFKA_API_KEY / KAFKA_API_SECRET (source export-env.sh <site>)")
    return Consumer(
        {
            "bootstrap.servers": bootstrap,
            "security.protocol": "SASL_SSL",
            "sasl.mechanisms": "PLAIN",
            "sasl.username": key,
            "sasl.password": secret,
            "group.id": f"peek-topic-{os.getpid()}",
            "enable.auto.commit": False,
            "enable.partition.eof": True,
            "log_level": 3,
        }
    )


def _fmt(msg) -> dict:
    _, ts = msg.timestamp()
    key_id, key = _decode(msg.key())
    val_id, value = _decode(msg.value())
    return {
        "partition": msg.partition(),
        "offset": msg.offset(),
        "timestamp": datetime.fromtimestamp(ts / 1000, tz=timezone.utc).isoformat(timespec="milliseconds") if ts > 0 else None,
        "key": key,
        "value": value,
        "schema_ids": {"key": key_id, "value": val_id},
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("topic")
    ap.add_argument("--last", type=int, default=10, help="Number of most recent messages to print (default 10)")
    ap.add_argument("--partition", type=int, default=None, help="Only this partition")
    ap.add_argument("--follow", action="store_true", help="Keep running and print new messages")
    ap.add_argument("--stats", action="store_true", help="Print offsets per partition and exit")
    args = ap.parse_args()

    c = _consumer()
    try:
        md = c.list_topics(args.topic, timeout=20)
        t = md.topics.get(args.topic)
        if t is None or t.error is not None:
            print(f"Topic {args.topic!r} not found: {t.error if t else 'unknown'}", file=sys.stderr)
            return 1
        parts = sorted(t.partitions) if args.partition is None else [args.partition]

        offsets = {p: c.get_watermark_offsets(TopicPartition(args.topic, p), timeout=20) for p in parts}
        total = sum(high - low for low, high in offsets.values())
        print(f"# {args.topic}: {len(parts)} partition(s), {total} retained messages", file=sys.stderr)
        for p in parts:
            low, high = offsets[p]
            print(f"#   partition {p}: offsets [{low}, {high}) = {high - low}", file=sys.stderr)
        if args.stats:
            return 0

        # Read the last N of every partition, then keep the N newest overall by timestamp.
        # Over-read by a margin: transactional writers (Flink exactly-once sinks) leave commit
        # markers at the tail. They count in the offsets but are never delivered, so starting
        # exactly N back can land on a marker and return fewer messages than asked for.
        margin = 20
        start = {p: max(offsets[p][0], offsets[p][1] - args.last - margin) for p in parts}
        c.assign([TopicPartition(args.topic, p, start[p]) for p in parts])
        pending = {p for p in parts if offsets[p][1] > start[p]}
        batch = []
        deadline = time.time() + 30
        while pending and time.time() < deadline:
            msg = c.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    pending.discard(msg.partition())
                continue
            batch.append(msg)
            if msg.offset() + 1 >= offsets[msg.partition()][1]:
                pending.discard(msg.partition())

        batch.sort(key=lambda m: (m.timestamp()[1], m.partition(), m.offset()))
        for m in batch[-args.last:]:
            print(json.dumps(_fmt(m), default=str))

        if args.follow:
            print("# following, Ctrl-C to stop", file=sys.stderr)
            while True:
                msg = c.poll(1.0)
                if msg is None or (msg.error() and msg.error().code() == KafkaError._PARTITION_EOF):
                    continue
                if msg.error():
                    print(f"# error: {msg.error()}", file=sys.stderr)
                    continue
                print(json.dumps(_fmt(msg), default=str), flush=True)
        return 0
    except KeyboardInterrupt:
        return 0
    finally:
        c.close()


if __name__ == "__main__":
    raise SystemExit(main())
