"""
Produce raw_tickets records to kafka topic.

Use JSON schema

Usage:
 cd python
    uv sync
    source ../../set_env.sh
    uv run produce_raw_events.py

    uv run produce_raw_events.py --count 20 --interval 0.5

testresults variation pattern (cycles per 3 records):
  i % 3 == 1  → field populated with a value
  i % 3 == 2  → field explicitly set to None (null in JSON)
  i % 3 == 0  → field omitted entirely from the payload
"""

import argparse
import sys
import time
from pathlib import Path
from datetime import datetime, timezone

from pydantic import BaseModel, AwareDatetime

DEFAULT_TOPIC = "raw_tickets"


def _flink_sql_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        lib = parent / "code" / "flink-sql" / "cm_py_lib" / "kafka_avro_producer.py"
        if lib.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib. Run from the flink-studies repo."
    )


def _setup_cm_py_lib() -> Path:
    root = _flink_sql_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    return root


_setup_cm_py_lib()
from cm_py_lib.kafka_json_producer import KafkaJSONProducer


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce raw_tickets JSON records")
    parser.add_argument(
        "--count",
        "-c",
        type=int,
        default=9,
        help="Number of events to produce (cycles through: populated / null / omitted)",
    )
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--interval", type=float, default=0.0)
    parser.add_argument("--no-schema-registry", action="store_true")
    return parser.parse_args()


class RawTicket(BaseModel):
    case_id: str
    description: str
    priority: int
    owner: str
    testresults: str | None = None
    creation_ts: AwareDatetime


def _build_record(i: int) -> RawTicket:
    """Build a RawTicket cycling through three testresults states.

    Cycle (1-based index mod 3):
      1 → testresults populated
      2 → testresults explicitly None  (null in JSON)
      0 → testresults omitted entirely (field not present in JSON)
    """
    idx = str(i)
    base = dict(
        case_id=f"case_{idx}",
        description=f"description_{idx}",
        priority=2,
        owner=f"owner_{idx}",
        creation_ts=datetime.now(timezone.utc),
    )

    remainder = i % 3
    if remainder == 1:
        # populated
        return RawTicket(**base, testresults=f"result_{idx}")
    elif remainder == 2:
        # explicitly null
        return RawTicket(**base, testresults=None)
    else:
        # omitted — construct without setting the field so model_dump(exclude_unset=True)
        # will not include it in the serialized payload
        return RawTicket.model_construct(**base)


def main() -> None:
    args = _parse_args()
    if args.count <= 0:
        raise ValueError("--count must be greater than 0")

    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=not args.no_schema_registry,
        model_class=RawTicket,
    )

    for i in range(1, args.count + 1):
        record = _build_record(i)
        remainder = i % 3
        label = {1: "populated", 2: "null", 0: "omitted"}[remainder]
        print(f"[{i}/{args.count}] testresults={label!r}  →  {record.model_dump_json(exclude_unset=True)}")
        producer.send_record(record.case_id, record)
        if args.interval > 0:
            time.sleep(args.interval)

    producer.flush_and_close()


if __name__ == "__main__":
    main()
