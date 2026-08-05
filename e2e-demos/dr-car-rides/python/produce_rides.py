"""Continuous car-ride event producer for the DR demo.

Writes to rides_raw with a monotonic seq (logged for loss assessment).
Uses Schema Registry JSON wire format when SCHEMA_REGISTRY_* is set.

Does not auto-register schemas. Flink DDL owns rides_raw-key / rides_raw-value
(redeploy with value.fields-include=all so driver_id is in key and value).

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
    from confluent_kafka.serialization import MessageField, SerializationContext
except ImportError as exc:  # pragma: no cover
    print(exc)
    raise SystemExit(
        "Install deps: uv sync  # or: pip install 'confluent-kafka[schema-registry,json]>=2.3' pydantic"
    ) from exc


CITIES = ["SEA", "PDX", "SFO", "LAX", "DEN", "AUS", "CHI", "NYC"]
STATUSES = ["completed", "completed", "completed", "cancelled", "invalid"]
DRIVERS = [f"drv-{i:03d}" for i in range(1, 21)]
RIDERS = [f"rdr-{i:04d}" for i in range(1, 201)]

# Match Flink json-registry wire encoding for TIMESTAMP(3): epoch millis (number).
_SR_SERDE_CONF = {
    "auto.register.schemas": False,
    "use.latest.version": True,
}


class CarRide(BaseModel):
    driver_id: str
    ride_id: str
    seq: int
    rider_id: str
    pickup_ts: int = Field(description="Epoch milliseconds (Flink TIMESTAMP)")
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


def _key_to_dict(obj, _ctx):
    if isinstance(obj, dict):
        return obj
    return {"driver_id": obj}


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
    sr = _sr_client()
    key_serializer = None
    json_serializer = None
    if sr is not None:
        # Schema owned by Flink DDL; do not register from Pydantic.
        key_serializer = JSONSerializer(None, sr, _key_to_dict, conf=_SR_SERDE_CONF)
        json_serializer = JSONSerializer(None, sr, _to_dict, conf=_SR_SERDE_CONF)

    seq = args.start_seq
    sent = 0
    mode = "SR json-registry (use.latest.version)" if sr else "plain JSON (no SR)"
    print(f"Producing to {args.topic} every {args.interval}s [{mode}]; seq log → {seq_path}")

    try:
        while True:
            now = datetime.now(timezone.utc)
            ride = CarRide(
                driver_id=random.choice(DRIVERS),
                ride_id=str(uuid.uuid4()),
                seq=seq,
                rider_id=random.choice(RIDERS),
                pickup_ts=int(now.timestamp() * 1000),
                fare_usd=round(random.uniform(5.0, 85.0), 2),
                status=random.choice(STATUSES),
                city=random.choice(CITIES),
            )
            key_obj = {"driver_id": ride.driver_id}
            if json_serializer is not None and key_serializer is not None:
                key = key_serializer(
                    key_obj, SerializationContext(args.topic, MessageField.KEY)
                )
                value = json_serializer(
                    ride, SerializationContext(args.topic, MessageField.VALUE)
                )
            else:
                key = json.dumps(key_obj).encode("utf-8")
                value = json.dumps(ride.model_dump()).encode("utf-8")

            producer.produce(
                topic=args.topic,
                key=key,
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
                            "ts": now.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                            "pickup_ts_ms": ride.pickup_ts,
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
