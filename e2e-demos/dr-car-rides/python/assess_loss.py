"""Assess replication RPO and processing gaps using producer seq log.

Compares:
  - producer high-water (seq log)
  - optional Kafka topic high-water (max seq sampled via consumer)
  - optional snapshot files of max seq observed on sinks before/after failover

Usage examples:
  uv run assess_loss.py --producer-log /tmp/dr-car-rides-seq.log
  uv run assess_loss.py --producer-log /tmp/dr-car-rides-seq.log \\
      --pre-failover-max-seq 1200 --post-mirror-max-seq 1185
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def _max_seq_from_log(path: Path) -> int | None:
    if not path.exists():
        return None
    max_seq = None
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
                s = int(rec["seq"])
                max_seq = s if max_seq is None else max(max_seq, s)
            except (json.JSONDecodeError, KeyError, TypeError, ValueError):
                continue
    return max_seq


def _sample_topic_max_seq(topic: str, timeout_s: float = 15.0) -> int | None:
    """Best-effort sample of max seq from a topic (requires Kafka env)."""
    try:
        from confluent_kafka import Consumer, TopicPartition
    except ImportError:
        return None

    bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap:
        return None

    conf = {
        "bootstrap.servers": bootstrap,
        "group.id": f"dr-rides-assess-{os.getpid()}",
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
    }
    api_key = os.environ.get("KAFKA_API_KEY")
    api_secret = os.environ.get("KAFKA_API_SECRET")
    if api_key and api_secret:
        conf.update(
            {
                "security.protocol": "SASL_SSL",
                "sasl.mechanisms": "PLAIN",
                "sasl.username": api_key,
                "sasl.password": api_secret,
            }
        )

    consumer = Consumer(conf)
    try:
        md = consumer.list_topics(topic, timeout=10)
        if topic not in md.topics or md.topics[topic].error is not None:
            return None
        partitions = [
            TopicPartition(topic, p)
            for p in md.topics[topic].partitions
        ]
        if not partitions:
            return None
        # Seek near end and sample recent messages
        for tp in partitions:
            low, high = consumer.get_watermark_offsets(tp, timeout=10)
            tp.offset = max(low, high - 200)
        consumer.assign(partitions)

        import time

        deadline = time.time() + timeout_s
        max_seq = None
        while time.time() < deadline:
            msg = consumer.poll(0.5)
            if msg is None or msg.error():
                continue
            try:
                payload = json.loads(msg.value().decode("utf-8"))
                # SR wire format: skip magic byte + schema id if present
            except Exception:
                raw = msg.value()
                if raw and raw[0] == 0 and len(raw) > 5:
                    # confluent wire format — try decode after header
                    try:
                        # Without SR deserializer, skip binary payloads
                        continue
                    except Exception:
                        continue
                continue
            if "seq" in payload:
                s = int(payload["seq"])
                max_seq = s if max_seq is None else max(max_seq, s)
        return max_seq
    finally:
        consumer.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Assess DR loss via seq")
    parser.add_argument("--producer-log", required=True, type=Path)
    parser.add_argument("--pre-failover-max-seq", type=int, default=None)
    parser.add_argument("--post-mirror-max-seq", type=int, default=None)
    parser.add_argument(
        "--sample-topic",
        default="",
        help="Optional topic to sample max seq from (plain JSON only)",
    )
    args = parser.parse_args()

    producer_hw = _max_seq_from_log(args.producer_log)
    report = {
        "producer_high_water_seq": producer_hw,
        "pre_failover_max_seq": args.pre_failover_max_seq,
        "post_mirror_max_seq": args.post_mirror_max_seq,
        "replication_rpo_estimate": None,
        "processing_gap_estimate": None,
        "notes": [],
    }

    if producer_hw is None:
        report["notes"].append(f"No seq found in {args.producer_log}")
    else:
        report["notes"].append(f"Producer high-water seq={producer_hw}")

    if args.pre_failover_max_seq is not None and args.post_mirror_max_seq is not None:
        report["replication_rpo_estimate"] = max(
            0, args.pre_failover_max_seq - args.post_mirror_max_seq
        )
        report["notes"].append(
            "replication_rpo_estimate = pre_failover_max_seq - post_mirror_max_seq "
            "(messages not yet mirrored at cutover)"
        )

    if producer_hw is not None and args.post_mirror_max_seq is not None:
        report["processing_gap_estimate"] = max(0, producer_hw - args.post_mirror_max_seq)
        report["notes"].append(
            "processing_gap_estimate vs producer includes unreplicated tail + unprocessed"
        )

    if args.sample_topic:
        sampled = _sample_topic_max_seq(args.sample_topic)
        report["sampled_topic"] = args.sample_topic
        report["sampled_max_seq"] = sampled
        if sampled is None:
            report["notes"].append(
                "Topic sample returned None (SR wire format needs deserializer; "
                "pass --post-mirror-max-seq from Flink/UI instead)"
            )

    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
