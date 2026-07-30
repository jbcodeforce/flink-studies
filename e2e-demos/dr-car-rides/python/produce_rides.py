"""Continuous car-ride event producer for the DR demo.

Writes to rides_raw with a monotonic seq (logged for loss assessment).
Uses Schema Registry JSON wire format when SCHEMA_REGISTRY_* is set.

Environment (via export-env.sh or manual):
  KAFKA_BOOTSTRAP_SERVERS, KAFKA_API_KEY, KAFKA_API_SECRET
  SCHEMA_REGISTRY_ENDPOINT, SCHEMA_REGISTRY_API_KEY, SCHEMA_REGISTRY_API_SECRET
  KAFKA_TOPIC (default: rides_raw)
"""

from __future__ import annotations

import argparse
import json
import os
import random
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel, Field

try:
    from confluent_kafka import Producer
    from confluent_kafka.schema_registry import SchemaRegistryClient
    from confluent_kafka.schema_registry.json_schema import JSONSerializer
    from confluent_kafka.serialization import MessageField, SerializationContext, StringSerializer
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Install deps: pip install 'confluent-kafka[schema-registry]>=2.3' pydantic"
    ) from exc


CITIES = ["SEA", "PDX", "SFO", "LAX", "DEN", "AUS", "CHI", "NYC"]
STATUSES = ["completed", "completed", "completed", "cancelled", "invalid"]
DRIVERS = [f"drv-{i:03d}" for i in range(1, 21)]
RIDERS = [f"rdr-{i:04d}" for i in range(1, 201)]


class CarRide(BaseModel):
    driver_id: str
    ride_id: str
    seq: int
    rider_id: str
    pickup_ts: str = Field(description="ISO-8601 timestamp")
    fare_usd: float
    status: str
    city: str


def _kafka_conf() -> dict:
    bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    conf: dict = {"bootstrap.servers": bootstrap}
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
    return conf


def _sr_client() -> SchemaRegistryClient | None:
    endpoint = os.environ.get("SCHEMA_REGISTRY_ENDPOINT")
    if not endpoint:
        return None
    conf: dict = {"url": endpoint}
    key = os.environ.get("SCHEMA_REGISTRY_API_KEY")
    secret = os.environ.get("SCHEMA_REGISTRY_API_SECRET")
    if key and secret:
        conf["basic.auth.user.info"] = f"{key}:{secret}"
    return SchemaRegistryClient(conf)


def _to_dict(obj, _ctx):
    if isinstance(obj, BaseModel):
        return obj.model_dump()
    return obj


def main() -> None:
    parser = argparse.ArgumentParser(description="Produce car-ride events continuously")
    parser.add_argument("--interval", type=float, default=0.5, help="Seconds between events")
    parser.add_argument("--topic", default=os.environ.get("KAFKA_TOPIC", "rides_raw"))
    parser.add_argument(
        "--seq-log",
        default=os.environ.get("SEQ_LOG", "/tmp/dr-car-rides-seq.log"),
        help="Append-only log of seq values for assess_loss",
    )
    parser.add_argument("--start-seq", type=int, default=1)
    parser.add_argument("--max-events", type=int, default=0, help="0 = run forever")
    args = parser.parse_args()

    seq_path = Path(args.seq_log)
    seq_path.parent.mkdir(parents=True, exist_ok=True)

    producer = Producer(_kafka_conf())
    string_serializer = StringSerializer("utf_8")
    sr = _sr_client()
    json_serializer = None
    if sr is not None:
        schema_str = json.dumps(CarRide.model_json_schema())
        json_serializer = JSONSerializer(schema_str, sr, _to_dict)

    seq = args.start_seq
    sent = 0
    print(f"Producing to {args.topic} every {args.interval}s; seq log → {seq_path}")

    try:
        while True:
            ride = CarRide(
                driver_id=random.choice(DRIVERS),
                ride_id=str(uuid.uuid4()),
                seq=seq,
                rider_id=random.choice(RIDERS),
                pickup_ts=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                fare_usd=round(random.uniform(5.0, 85.0), 2),
                status=random.choice(STATUSES),
                city=random.choice(CITIES),
            )
            key = ride.driver_id
            if json_serializer is not None:
                value = json_serializer(
                    ride, SerializationContext(args.topic, MessageField.VALUE)
                )
            else:
                value = json.dumps(ride.model_dump()).encode("utf-8")

            producer.produce(
                topic=args.topic,
                key=string_serializer(key),
                value=value,
            )
            producer.poll(0)
            with seq_path.open("a", encoding="utf-8") as fh:
                fh.write(
                    json.dumps(
                        {
                            "seq": seq,
                            "ride_id": ride.ride_id,
                            "driver_id": ride.driver_id,
                            "status": ride.status,
                            "ts": ride.pickup_ts,
                        }
                    )
                    + "\n"
                )

            seq += 1
            sent += 1
            if args.max_events and sent >= args.max_events:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nStopping producer...")
    finally:
        producer.flush()
        print(f"Sent {sent} events; last seq={seq - 1}")


if __name__ == "__main__":
    main()
