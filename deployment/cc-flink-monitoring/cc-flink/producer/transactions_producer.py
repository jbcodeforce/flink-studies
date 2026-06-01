#!/usr/bin/env python3
"""Produce one year of transactions with steadily progressing event time."""

from __future__ import annotations

import argparse
import os
import random
import time
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Iterable
from uuid import uuid4

from dotenv import load_dotenv

USER_ID_TEMPLATE = "user_{:03d}"
AMOUNT_QUANTIZER = Decimal("0.01")

KEY_SCHEMA = """
{
  "type": "record",
  "name": "raw_transactions_key",
  "fields": [
    {"name": "transaction_id", "type": "string"}
  ]
}
"""

VALUE_SCHEMA = """
{
  "type": "record",
  "name": "raw_transactions_value",
  "fields": [
    {"name": "transaction_id", "type": "string"},
    {"name": "user_id", "type": "string"},
    {
      "name": "amount",
      "type": {
        "type": "bytes",
        "logicalType": "decimal",
        "precision": 12,
        "scale": 2
      }
    },
    {
      "name": "ts",
      "type": {
        "type": "long",
        "logicalType": "timestamp-millis"
      }
    }
  ]
}
"""


@dataclass(frozen=True)
class ProducerPlan:
    users: int = 100
    days: int = 365
    tx_per_user_per_day: int = 2
    min_amount: Decimal = Decimal("5.00")
    max_amount: Decimal = Decimal("250.00")

    @property
    def total_transactions(self) -> int:
        return self.users * self.days * self.tx_per_user_per_day


def load_confluent_env() -> Path:
    """Load Confluent credentials from ~/.confluent/.env (or CONFLUENT_ENV_FILE)."""
    env_file = Path(
        os.environ.get("CONFLUENT_ENV_FILE", str(Path.home() / ".confluent" / ".env"))
    )
    if not env_file.exists():
        raise FileNotFoundError(f"Confluent env file not found: {env_file}")
    load_dotenv(env_file, override=False)
    return env_file


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def env_value(*names: str) -> str:
    """Return the first non-empty environment variable from the given names."""
    for name in names:
        raw = os.environ.get(name)
        if raw is None:
            continue
        value = _strip_quotes(raw)
        if value and not value.startswith("${"):
            return value
    return ""


def build_kafka_config() -> dict[str, str]:
    """Build Confluent Cloud Kafka producer settings from environment variables."""
    bootstrap = env_value("KAFKA_BOOTSTRAP_SERVERS", "BOOTSTRAP_SERVERS")
    api_key = env_value("KAFKA_API_KEY")
    api_secret = env_value("KAFKA_API_SECRET")

    missing = []
    if not bootstrap:
        missing.append("KAFKA_BOOTSTRAP_SERVERS or BOOTSTRAP_SERVERS")
    if not api_key:
        missing.append("KAFKA_API_KEY")
    if not api_secret:
        missing.append("KAFKA_API_SECRET")
    if missing:
        raise ValueError(
            "Missing required Kafka settings in ~/.confluent/.env: "
            + ", ".join(missing)
        )

    return {
        "bootstrap.servers": bootstrap,
        "security.protocol": env_value("KAFKA_SECURITY_PROTOCOL") or "SASL_SSL",
        "sasl.mechanism": env_value("KAFKA_SASL_MECHANISM") or "PLAIN",
        "sasl.username": api_key,
        "sasl.password": api_secret,
        "acks": "all",
    }


def transaction_to_avro(record: dict[str, Any], _ctx) -> dict[str, Any]:
    """Convert a transaction record for Avro serialization."""
    ts = record["ts"]
    if isinstance(ts, datetime):
        ts_ms = int(ts.timestamp() * 1000)
    else:
        ts_ms = ts
    return {
        "transaction_id": record["transaction_id"],
        "user_id": record["user_id"],
        "amount": record["amount"],
        "ts": ts_ms,
    }


def ensure_topic_exists(kafka_config: dict[str, str], topic: str, partitions: int = 1) -> None:
    """Create the Kafka topic when it does not exist (Confluent Cloud)."""
    from confluent_kafka.admin import AdminClient, NewTopic

    admin = AdminClient(kafka_config)
    metadata = admin.list_topics(timeout=15)
    if topic in metadata.topics and metadata.topics[topic].error is None:
        return

    replication_factor = int(env_value("KAFKA_REPLICATION_FACTOR") or "3")
    futures = admin.create_topics(
        [NewTopic(topic, num_partitions=partitions, replication_factor=replication_factor)]
    )
    for topic_name, future in futures.items():
        try:
            future.result(timeout=30)
            print(f"Created Kafka topic '{topic_name}'.")
        except Exception as exc:
            if "TOPIC_ALREADY_EXISTS" in str(exc):
                return
            raise RuntimeError(f"Failed to create topic '{topic_name}': {exc}") from exc


def build_schema_registry_config() -> dict[str, str]:
    """Build Schema Registry client settings from environment variables."""
    url = env_value("SCHEMA_REGISTRY_ENDPOINT", "SCHEMA_REGISTRY_URL")
    api_key = env_value("SCHEMA_REGISTRY_API_KEY", "SCHEMA_REGISTRY_KEY")
    api_secret = env_value("SCHEMA_REGISTRY_API_SECRET", "SCHEMA_REGISTRY_SECRET")

    missing = []
    if not url:
        missing.append("SCHEMA_REGISTRY_ENDPOINT or SCHEMA_REGISTRY_URL")
    if not api_key:
        missing.append("SCHEMA_REGISTRY_API_KEY or SCHEMA_REGISTRY_KEY")
    if not api_secret:
        missing.append("SCHEMA_REGISTRY_API_SECRET or SCHEMA_REGISTRY_SECRET")
    if missing:
        raise ValueError(
            "Missing required Schema Registry settings in ~/.confluent/.env: "
            + ", ".join(missing)
        )

    return {
        "url": url,
        "basic.auth.user.info": f"{api_key}:{api_secret}",
    }


def progressive_timestamps(
    total_rows: int, start_ts: datetime, end_ts: datetime
) -> Iterable[datetime]:
    """Yield strictly non-decreasing timestamps over the configured span."""
    if total_rows <= 0:
        return
    if total_rows == 1:
        yield start_ts
        return

    span_ms = int((end_ts - start_ts).total_seconds() * 1000)
    for idx in range(total_rows):
        offset_ms = int((idx * span_ms) / (total_rows - 1))
        yield start_ts + timedelta(milliseconds=offset_ms)


def build_transactions(plan: ProducerPlan, rng: random.Random) -> Iterable[dict[str, Any]]:
    """Create transaction records that match the Flink transactions schema."""
    end_ts = datetime.now(UTC)
    start_ts = end_ts - timedelta(days=plan.days)
    per_day = plan.users * plan.tx_per_user_per_day

    for idx, ts in enumerate(
        progressive_timestamps(plan.total_transactions, start_ts, end_ts)
    ):
        user_index = (idx % per_day) // plan.tx_per_user_per_day + 1
        amount = Decimal(str(rng.uniform(float(plan.min_amount), float(plan.max_amount))))
        yield {
            "transaction_id": str(uuid4()),
            "user_id": USER_ID_TEMPLATE.format(user_index),
            "amount": amount.quantize(AMOUNT_QUANTIZER, rounding=ROUND_HALF_UP),
            "ts": ts,
        }


def create_serializers(
    schema_registry_config: dict[str, str],
):
    """Create Schema Registry Avro serializers for transaction key and value."""
    from confluent_kafka.schema_registry import SchemaRegistryClient
    from confluent_kafka.schema_registry.avro import AvroSerializer

    client = SchemaRegistryClient(schema_registry_config)
    key_serializer = AvroSerializer(client, KEY_SCHEMA, lambda obj, _ctx: obj)
    value_serializer = AvroSerializer(client, VALUE_SCHEMA, transaction_to_avro)
    return key_serializer, value_serializer


def produce_transactions(
    kafka_config: dict[str, str],
    schema_registry_config: dict[str, str],
    topic: str,
    plan: ProducerPlan,
    rows_per_second: int,
    seed: int,
) -> None:
    """Produce historical transaction data to Kafka with Avro + Schema Registry."""
    from confluent_kafka import Producer
    from confluent_kafka.serialization import MessageField, SerializationContext

    if rows_per_second <= 0:
        raise ValueError("--rows-per-second must be greater than 0")

    ensure_topic_exists(kafka_config, topic)
    producer = Producer(kafka_config)
    key_serializer, value_serializer = create_serializers(schema_registry_config)
    rng = random.Random(seed)

    delivered = 0
    delivery_errors: list[str] = []
    start_monotonic = time.monotonic()

    def on_delivery(err, _msg) -> None:
        if err is not None:
            delivery_errors.append(str(err))

    for index, transaction in enumerate(build_transactions(plan, rng), start=1):
        key_payload = {"transaction_id": transaction["transaction_id"]}
        key = key_serializer(key_payload, SerializationContext(topic, MessageField.KEY))
        value = value_serializer(
            transaction, SerializationContext(topic, MessageField.VALUE)
        )
        producer.produce(topic=topic, key=key, value=value, on_delivery=on_delivery)
        producer.poll(0)
        delivered += 1

        # Keep throughput near the requested rows/s while preserving event-time order.
        expected_elapsed = index / rows_per_second
        remaining = expected_elapsed - (time.monotonic() - start_monotonic)
        if remaining > 0:
            time.sleep(remaining)

    producer.flush()
    if delivery_errors:
        raise RuntimeError(f"Encountered {len(delivery_errors)} delivery errors")
    print(
        f"Produced {delivered} records to topic '{topic}' "
        f"({plan.users} users, {plan.days} days, {plan.tx_per_user_per_day} tx/user/day)."
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Produce transactions with strictly progressing event timestamps "
            "over a historical window."
        ),
    )
    parser.add_argument(
        "--topic",
        default="raw_transactions",
        help="Kafka topic name (default: raw_transactions).",
    )
    parser.add_argument("--users", type=int, default=100)
    parser.add_argument("--days", type=int, default=365)
    parser.add_argument("--tx-per-user-per-day", type=int, default=2)
    parser.add_argument("--rows-per-second", type=int, default=100)
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducible amount generation.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.users <= 0 or args.days <= 0 or args.tx_per_user_per_day <= 0:
        raise ValueError("--users, --days, and --tx-per-user-per-day must be greater than 0")

    load_confluent_env()
    kafka_config = build_kafka_config()
    schema_registry_config = build_schema_registry_config()

    plan = ProducerPlan(
        users=args.users,
        days=args.days,
        tx_per_user_per_day=args.tx_per_user_per_day,
    )
    produce_transactions(
        kafka_config=kafka_config,
        schema_registry_config=schema_registry_config,
        topic=args.topic,
        plan=plan,
        rows_per_second=args.rows_per_second,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()
