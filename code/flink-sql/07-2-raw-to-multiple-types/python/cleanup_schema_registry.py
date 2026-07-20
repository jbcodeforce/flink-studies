#!/usr/bin/env python3
"""
Clean Kafka topic(s) and Schema Registry subjects for the 07-2 demo.

By default deletes:

- Kafka topic ``raw_account_events``
- Schema Registry ``raw_account_events-value`` (and ``raw_account_events-key`` if present)
- Leftover RecordNameStrategy subjects from earlier demo variants

Usage::

    cd python
    source ../../set_env.sh
    uv run cleanup_schema_registry.py
    uv run cleanup_schema_registry.py --include-sink
    uv run cleanup_schema_registry.py --dry-run
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_DEMO_PYTHON = Path(__file__).resolve().parent
if str(_DEMO_PYTHON) not in sys.path:
    sys.path.insert(0, str(_DEMO_PYTHON))

from _common import setup_cm_py_lib  # noqa: E402

setup_cm_py_lib()
from cm_py_lib.kafka_json_producer import (  # noqa: E402
    SCHEMA_REGISTRY_PASSWORD,
    SCHEMA_REGISTRY_URL,
    SCHEMA_REGISTRY_USER,
    _is_subject_not_found,
    _kafka_client_config,
)
from confluent_kafka.admin import AdminClient  # noqa: E402
from confluent_kafka.schema_registry import SchemaRegistryClient  # noqa: E402
from confluent_kafka.schema_registry.error import SchemaRegistryError  # noqa: E402

DEFAULT_TOPIC = "raw_account_events"
NS = "io.confluent.flink.multievent"

LEFTOVER_RECORD_SUBJECTS = (
    f"{NS}.DeviceSwapEvent",
    f"{NS}.SubscriptionEvent",
    f"{NS}.DeviceCloseEvent",
)

SINK_TOPIC = "account_events"
SINK_SUBJECTS = (
    f"{SINK_TOPIC}-value",
    f"{SINK_TOPIC}-key",
)


def _sr_client() -> SchemaRegistryClient:
    conf: dict[str, str] = {"url": SCHEMA_REGISTRY_URL}
    if SCHEMA_REGISTRY_USER:
        conf["basic.auth.user.info"] = (
            f"{SCHEMA_REGISTRY_USER}:{SCHEMA_REGISTRY_PASSWORD}"
        )
    print("=== Schema Registry Configuration ===")
    print(f"URL: {conf['url']}")
    print(f"Auth enabled: {bool(SCHEMA_REGISTRY_USER)}")
    print("====================================")
    return SchemaRegistryClient(conf)


def _delete_topic(topic: str, *, dry_run: bool) -> None:
    if dry_run:
        print(f"[dry-run] would delete Kafka topic '{topic}'")
        return
    admin = AdminClient(_kafka_client_config())
    metadata = admin.list_topics(timeout=15)
    if topic not in metadata.topics or metadata.topics[topic].error is not None:
        print(f"Kafka topic '{topic}' not found (skip)")
        return
    futures = admin.delete_topics([topic], operation_timeout=30)
    for name, future in futures.items():
        try:
            future.result(timeout=60)
            print(f"Deleted Kafka topic '{name}'")
        except Exception as exc:
            print(f"Failed to delete Kafka topic '{name}': {exc}")
            raise


def _delete_subject(
    client: SchemaRegistryClient,
    subject: str,
    *,
    dry_run: bool,
) -> None:
    if dry_run:
        print(f"[dry-run] would delete subject '{subject}' (soft + permanent)")
        return
    try:
        versions = client.delete_subject(subject)
        print(f"Soft-deleted '{subject}' versions={versions}")
    except SchemaRegistryError as exc:
        if _is_subject_not_found(exc):
            print(f"Subject '{subject}' not found (skip soft-delete)")
        else:
            raise
    try:
        versions = client.delete_subject(subject, permanent=True)
        print(f"Permanently deleted '{subject}' versions={versions}")
    except SchemaRegistryError as exc:
        if _is_subject_not_found(exc):
            print(f"Subject '{subject}' not found (skip permanent-delete)")
        else:
            raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Delete raw_account_events Kafka topic and related Schema Registry "
            "subjects for the 07-2 demo"
        )
    )
    parser.add_argument(
        "--topic",
        default=DEFAULT_TOPIC,
        help="Source topic to delete (also deletes {topic}-value / {topic}-key subjects)",
    )
    parser.add_argument(
        "--include-sink",
        action="store_true",
        help="Also delete account_events topic and its key/value subjects",
    )
    parser.add_argument(
        "--keep-topic",
        action="store_true",
        help="Only delete Schema Registry subjects (do not delete Kafka topics)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without calling Kafka or Schema Registry",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    topics = [args.topic]
    subjects = [
        f"{args.topic}-value",
        f"{args.topic}-key",
        *LEFTOVER_RECORD_SUBJECTS,
    ]
    if args.include_sink:
        topics.append(SINK_TOPIC)
        subjects.extend(SINK_SUBJECTS)

    seen_t: set[str] = set()
    unique_topics = [t for t in topics if not (t in seen_t or seen_t.add(t))]
    seen_s: set[str] = set()
    unique_subjects = [s for s in subjects if not (s in seen_s or seen_s.add(s))]

    if not args.keep_topic:
        print("Kafka topics to delete:")
        for topic in unique_topics:
            print(f"  - {topic}")
    print("Schema Registry subjects to delete:")
    for subject in unique_subjects:
        print(f"  - {subject}")

    if not args.keep_topic:
        for topic in unique_topics:
            _delete_topic(topic, dry_run=args.dry_run)

    client = _sr_client()
    for subject in unique_subjects:
        _delete_subject(client, subject, dry_run=args.dry_run)

    print("Cleanup done.")


if __name__ == "__main__":
    main()
