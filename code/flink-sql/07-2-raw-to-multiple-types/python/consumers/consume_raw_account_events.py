#!/usr/bin/env python3
"""
Consume raw_account_events while ignoring Schema Registry.

Reads Kafka values as bytes, peels the Confluent wire-format prefix
(magic + 4-byte schema id), and prints the UTF-8 JSON body.

Usage::

    cd python
    uv sync
    source ../../set_env.sh
    uv run consumers/consume_raw_account_events.py --max-messages 3
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

# Bootstrap: demo python root + cm_py_lib
_DEMO_PYTHON = Path(__file__).resolve().parents[1]
if str(_DEMO_PYTHON) not in sys.path:
    sys.path.insert(0, str(_DEMO_PYTHON))

from _common import setup_cm_py_lib  # noqa: E402

setup_cm_py_lib()
from cm_py_lib.kafka_json_producer import _kafka_client_config  # noqa: E402
from confluent_kafka import Consumer, KafkaError, KafkaException  # noqa: E402

DEFAULT_TOPIC = "raw_account_events"
WIRE_PREFIX_LEN = 5


def parse_wire_payload(value: bytes) -> tuple[int | None, dict | str]:
    """Return (schema_id, payload) without using Schema Registry."""
    if len(value) < WIRE_PREFIX_LEN or value[0] != 0:
        try:
            return None, json.loads(value.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None, value.hex()

    schema_id = struct.unpack(">I", value[1:5])[0]
    body = value[WIRE_PREFIX_LEN:]
    try:
        return schema_id, json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return schema_id, body.hex()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Consume raw_account_events as bytes (ignore Schema Registry)"
    )
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument(
        "--group-id",
        default="e072-raw-consumer",
        help="Kafka consumer group id",
    )
    parser.add_argument(
        "--max-messages",
        "-n",
        type=int,
        default=3,
        help="Stop after N messages (0 = run until Ctrl-C)",
    )
    parser.add_argument(
        "--from-beginning",
        action="store_true",
        help="Start from earliest offset (default: latest)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    conf = {
        **_kafka_client_config(),
        "group.id": args.group_id,
        "auto.offset.reset": "earliest" if args.from_beginning else "latest",
        "enable.auto.commit": True,
    }
    consumer = Consumer(conf)
    consumer.subscribe([args.topic])
    print(
        f"Consuming {args.topic} (ignore SR, wire-prefix strip). "
        f"max_messages={args.max_messages or '∞'}"
    )

    seen = 0
    try:
        while args.max_messages == 0 or seen < args.max_messages:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                raise KafkaException(msg.error())

            key = msg.key().decode("utf-8") if msg.key() else None
            value = msg.value() or b""
            schema_id, payload = parse_wire_payload(value)
            seen += 1
            print("---")
            print(f"#{seen} partition={msg.partition()} offset={msg.offset()}")
            print(f"key={key}")
            print(f"schema_id={schema_id} value_len={len(value)}")
            print(f"payload={json.dumps(payload, indent=2) if isinstance(payload, dict) else payload}")
    except KeyboardInterrupt:
        print("Interrupted")
    finally:
        consumer.close()
        print(f"Closed after {seen} message(s)")


if __name__ == "__main__":
    main()
