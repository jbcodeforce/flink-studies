#!/usr/bin/env python3
"""Produce Airbnb CSV records to Confluent Kafka topics.

Reads the raw CSV files from the sibling ``airbnb`` project (``airbnb/data/``)
and publishes every row as a JSON record to a Kafka topic, feeding the
``airbnb_streaming`` dbt / Confluent Flink pipeline:

    hosts.csv    -> raw_hosts    (key: host_id)
    listings.csv -> raw_listings (key: listing_id)
    reviews.csv  -> raw_reviews  (key: listing_id)

Kafka plumbing (auth, topic bootstrap, Schema Registry) is reused from the
shared ``code/flink-sql/cm_py_lib`` library, whose configuration is
environment-driven. Every run ensures each target topic exists and that its
``{topic}-value`` JSON schema is registered in Schema Registry before
producing (schema-only in plain mode; wire-format encoded with
``--schema-registry``):

    KAFKA_BOOTSTRAP_SERVERS   broker list, e.g. pkc-xxx.us-west-2.aws.confluent.cloud:9092
    KAFKA_API_KEY             Confluent API key (producer role on the cluster)
    KAFKA_API_SECRET          Confluent API secret
    KAFKA_SECURITY_PROTOCOL   SASL_SSL is auto-inferred for Confluent Cloud
    KAFKA_PARTITIONS          partitions when creating topics (default 1)
    KAFKA_REPLICATION_FACTOR  replication factor (default 3 for non-plaintext)
    SCHEMA_REGISTRY_ENDPOINT  registry URL (only with --schema-registry)

Confluent Cloud example::

    export KAFKA_BOOTSTRAP_SERVERS="pkc-xxxxx.us-west-2.aws.confluent.cloud:9092"
    export KAFKA_API_KEY=...
    export KAFKA_API_SECRET=...
    uv run python scripts/produce_to_kafka.py

Local plain Kafka::

    uv run python scripts/produce_to_kafka.py 

Quick local checks (no Kafka connection)::

    uv run python scripts/produce_to_kafka.py --dry-run
    uv run python scripts/produce_to_kafka.py --dry-run --limit 10 --files hosts

CLI options are mirrored into the environment before the cm_py_lib module is
imported (it reads the environment at import time).
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import signal
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Optional

logger = logging.getLogger("airbnb.produce")

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_DATA_DIR = SCRIPT_DIR.parent.parent / "airbnb" / "data"


# ---------------------------------------------------------------------------
# Reuse the shared cm_py_lib (code/flink-sql) Kafka helpers.
# Same discovery pattern as the flink-sql demo producers.
# ---------------------------------------------------------------------------


def flink_sql_root() -> Path:
    for parent in SCRIPT_DIR.parents:
        lib = parent / "code" / "flink-sql" / "cm_py_lib" / "kafka_json_producer.py"
        if lib.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib. Run inside the flink-studies repo."
    )


def setup_cm_py_lib() -> None:
    root = flink_sql_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))


def import_cm_py_lib():
    """Import cm_py_lib helpers after environment is populated (it reads env
    variables at import time)."""
    setup_cm_py_lib()
    from cm_py_lib import kafka_json_producer as cm

    return cm


# ---------------------------------------------------------------------------
# Per-file definitions: CSV file, topic, key + value transformation.
# The transformation keeps the raw CSV fields (as strings) and adds a few
# typed convenience fields for downstream Flink models.
# ---------------------------------------------------------------------------


def _parse_price(raw: str) -> Optional[float]:
    """Parse a price like '$90.00' into a float (None when unparseable)."""
    if not raw:
        return None
    try:
        return float(raw.replace("$", "").replace(",", "").strip())
    except ValueError:
        return None


def _parse_bool(raw: Optional[str]) -> Optional[bool]:
    """Map 't'/'f' booleans to True/False/None."""
    value = (raw or "").strip().lower()
    if value in ("t", "true", "yes"):
        return True
    if value in ("f", "false", "no"):
        return False
    return None


def _parse_int(raw: Optional[str]) -> Optional[int]:
    try:
        return int((raw or "").strip())
    except (ValueError, AttributeError):
        return None


def _clean(raw: Optional[str]) -> Optional[str]:
    """Strip whitespace; empty strings become None (null in JSON)."""
    if raw is None:
        return None
    value = raw.strip()
    return value or None


def transform_hosts(row: dict[str, str]) -> tuple[str, dict[str, Any]]:
    value = {
        "host_id": _clean(row.get("id")),
        "host_name": _clean(row.get("name")),
        "is_superhost": _parse_bool(row.get("is_superhost")),
        "created_at": _clean(row.get("created_at")),
        "updated_at": _clean(row.get("updated_at")),
    }
    return value["host_id"] or "", value


def transform_listings(row: dict[str, str]) -> tuple[str, dict[str, Any]]:
    value = {
        "listing_id": _clean(row.get("id")),
        "listing_url": _clean(row.get("listing_url")),
        "listing_name": _clean(row.get("name")),
        "room_type": _clean(row.get("room_type")),
        "minimum_nights": _parse_int(row.get("minimum_nights")),
        "host_id": _clean(row.get("host_id")),
        "price_str": _clean(row.get("price")),
        "price": _parse_price(row.get("price")),
        "created_at": _clean(row.get("created_at")),
        "updated_at": _clean(row.get("updated_at")),
    }
    return value["listing_id"] or "", value


def transform_reviews(row: dict[str, str]) -> tuple[str, dict[str, Any]]:
    value = {
        "listing_id": _clean(row.get("listing_id")),
        "date": _clean(row.get("date")),
        "reviewer_name": _clean(row.get("reviewer_name")),
        "comments": _clean(row.get("comments")),
        "sentiment": _clean(row.get("sentiment")),
    }
    return value["listing_id"] or "", value


@dataclass(frozen=True)
class CsvSource:
    name: str
    file: str
    topic: str
    transform: Callable[[dict[str, str]], tuple[str, dict[str, Any]]]


#: Default referential order: hosts before listings, listings before reviews.
SOURCES: tuple[CsvSource, ...] = (
    CsvSource("hosts", "hosts.csv", "raw_hosts", transform_hosts),
    CsvSource("listings", "listings.csv", "raw_listings", transform_listings),
    CsvSource("reviews", "reviews.csv", "raw_reviews", transform_reviews),
)


# ---------------------------------------------------------------------------
# Produce stats / firehose loop
# ---------------------------------------------------------------------------


@dataclass
class ProduceStats:
    topic: str
    records: int = 0
    delivered: int = 0
    failed: int = 0
    in_flight: int = 0
    errors: list[str] = field(default_factory=list)


def produce_source(
    producer,
    source: CsvSource,
    args: argparse.Namespace,
    value_encoder: Optional[Callable[[dict[str, Any]], bytes]] = None,
) -> ProduceStats:
    """
    Stream one CSV file into Kafka, row by row (constant memory).
    """
    csv_path = Path(args.data_dir) / source.file
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    stats = ProduceStats(topic=source.topic)
    started = time.monotonic()

    def _delivery_report(error, message):
        if error is not None:
            stats.failed += 1
            stats.in_flight -= 1
            if len(stats.errors) < 10:
                stats.errors.append(str(error))
            logger.error("Delivery failed on topic '%s': %s", source.topic, error)
        else:
            stats.delivered += 1
            stats.in_flight -= 1

    logger.info(
        "Producing '%s' -> topic '%s' (%s)",
        csv_path.name,
        source.topic,
        "DRY RUN" if args.dry_run else "live",
    )

    with open(csv_path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for line_no, row in enumerate(reader, start=2):
            if args.limit and line_no - 1 > args.limit:
                break

            try:
                key, value = source.transform(row)
            except Exception as exc:  # noqa: BLE001 - keep the stream alive
                stats.failed += 1
                if len(stats.errors) < 10:
                    stats.errors.append(f"line {line_no}: {exc}")
                continue

            stats.records += 1
            if args.dry_run:
                continue

            if value_encoder is not None:
                # Schema Registry mode: encode through the cm_py_lib serializer.
                payload = value_encoder(value)
            else:
                payload = json.dumps(value, ensure_ascii=False).encode("utf-8")

            while True:
                try:
                    producer.produce(
                        topic=source.topic,
                        key=(key or "").encode("utf-8") or None,
                        value=payload,
                        callback=_delivery_report,
                    )
                    break
                except BufferError:
                    # Local librdkafka queue is full (large file producing faster
                    # than the broker can drain it): block briefly on delivery
                    # callbacks to free up space, then retry.
                    producer.poll(0.5)
            stats.in_flight += 1
            producer.poll(0)  # trigger delivery callbacks

            if stats.records % args.progress_every == 0:
                logger.info(
                    "  %s: %d records (in-flight=%d, failed=%d)",
                    source.topic,
                    stats.records,
                    stats.in_flight,
                    stats.failed,
                )

    if not args.dry_run:
        remaining = producer.flush(timeout=args.flush_timeout)
        if remaining:
            logger.warning("  %s: %d messages still queued after flush timeout", source.topic, remaining)

    elapsed = time.monotonic() - started
    rate = stats.records / elapsed if elapsed else 0.0
    logger.info(
        "  %s: %d records in %.1fs (%.0f rec/s) | delivered=%d failed=%d in_flight=%d",
        source.topic,
        stats.records,
        elapsed,
        rate,
        stats.delivered,
        stats.failed,
        stats.in_flight,
    )
    for error in stats.errors:
        logger.warning("  %s: sample error: %s", source.topic, error)
    return stats


def ensure_schema_registered(cm, model_class, topic: str) -> None:
    """Register the ``{topic}-value`` JSON schema if it isn't already there.

    Plain (non-``--schema-registry``) mode still produces raw JSON on the
    wire; this only publishes the schema so the topic has a documented
    contract in Schema Registry, mirroring what
    ``cm_py_lib.KafkaJSONProducer`` does automatically in wire-format mode.
    """
    from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
    from confluent_kafka.schema_registry.error import SchemaRegistryError

    conf = {"url": cm.SCHEMA_REGISTRY_URL}
    if cm.SCHEMA_REGISTRY_USER:
        conf["basic.auth.user.info"] = f"{cm.SCHEMA_REGISTRY_USER}:{cm.SCHEMA_REGISTRY_PASSWORD}"
    sr_client = SchemaRegistryClient(conf)

    subject = f"{topic}-value"
    try:
        sr_client.get_latest_version(subject)
        return
    except SchemaRegistryError as exc:
        if not cm._is_subject_not_found(exc):
            raise

    schema_dict = cm.prepare_json_schema_for_registry(model_class.model_json_schema(), model_class)
    schema_id = sr_client.register_schema(subject, Schema(json.dumps(schema_dict), schema_type="JSON"))
    logger.info("Registered schema version %s for subject '%s'", schema_id, subject)


def build_sr_encoder(cm, kp) -> Callable[[dict[str, Any]], bytes]:
    """Encode through the JSONSerializer configured by a cm_py_lib
    KafkaJSONProducer (bound to its topic)."""
    from confluent_kafka.serialization import MessageField, SerializationContext

    if kp.value_serializer is None:
        raise RuntimeError(
            f"Schema Registry serializer not initialized for topic '{kp.topic_name}'"
        )
    context = SerializationContext(kp.topic_name, MessageField.VALUE)

    def encode(value: dict[str, Any]) -> bytes:
        return kp.value_serializer(value, context)

    return encode


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _env_first(*names: str, default: str = "") -> str:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return default


def parse_files(raw: str) -> list[CsvSource]:
    """Resolve a comma-separated list of names to CsvSource definitions."""
    wanted = {name.strip() for name in raw.split(",") if name.strip()}
    unknown = wanted - {source.name for source in SOURCES}
    if unknown:
        raise SystemExit(
            f"Unknown file(s) {sorted(unknown)}. Available: {', '.join(s.name for s in SOURCES)}"
        )
    return [source for source in SOURCES if source.name in wanted]


def parse_topics(raw: str) -> dict[str, str]:
    """Parse 'name=topic,name=topic' overrides."""
    overrides: dict[str, str] = {}
    for pair in raw.split(","):
        if not pair.strip():
            continue
        name, _, topic = pair.partition("=")
        if not topic:
            raise SystemExit(f"Invalid --topics entry '{pair}', expected name=topic")
        overrides[name.strip()] = topic.strip()
    return overrides


def with_topic(source: CsvSource, args: argparse.Namespace, overrides: dict[str, str]) -> CsvSource:
    topic = overrides.get(source.name, source.topic)
    if args.topic_prefix:
        topic = f"{args.topic_prefix}{topic}"
    return CsvSource(source.name, source.file, topic, source.transform)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Produce Airbnb CSV records (airbnb/data) to Confluent Kafka.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--bootstrap-servers",
        default=_env_first("KAFKA_BOOTSTRAP_SERVERS", default="localhost:9092"),
        help="Kafka bootstrap servers (env KAFKA_BOOTSTRAP_SERVERS).",
    )
    parser.add_argument(
        "--api-key",
        default=_env_first("KAFKA_API_KEY", "CONFLUENT_API_KEY", "FLINK_API_KEY"),
        help="Confluent API key (env KAFKA_API_KEY/CONFLUENT_API_KEY/FLINK_API_KEY). Enables SASL/SSL.",
    )
    parser.add_argument(
        "--api-secret",
        default=_env_first("KAFKA_API_SECRET", "CONFLUENT_API_SECRET", "FLINK_API_SECRET"),
        help="Confluent API secret (env KAFKA_API_SECRET/CONFLUENT_API_SECRET/FLINK_API_SECRET).",
    )
    parser.add_argument(
        "--security-protocol",
        default=os.environ.get("KAFKA_SECURITY_PROTOCOL", ""),
        help="SASL_SSL / PLAINTEXT (auto-inferred for Confluent Cloud when API keys are set).",
    )
    parser.add_argument(
        "--data-dir",
        default=str(DEFAULT_DATA_DIR),
        help="Directory containing hosts.csv, listings.csv, reviews.csv.",
    )
    parser.add_argument(
        "--files",
        default="hosts,listings,reviews",
        help="Comma-separated subset of files to produce (hosts,listings,reviews).",
    )
    parser.add_argument(
        "--topics",
        default="",
        help="Topic overrides, e.g. 'listings=raw.listings,reviews=raw.reviews'.",
    )
    parser.add_argument(
        "--topic-prefix",
        default="",
        help="Prefix applied to all topics (e.g. 'raw.' -> raw.listings).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Produce at most N records per file (0 = whole file).",
    )
    parser.add_argument(
        "--partitions",
        type=int,
        default=int(os.environ.get("KAFKA_PARTITIONS", "1")),
        help="Partitions for created topics (env KAFKA_PARTITIONS).",
    )
    parser.add_argument(
        "--replication-factor",
        type=int,
        default=int(os.environ.get("KAFKA_REPLICATION_FACTOR", "0") or 0),
        help="Replication factor for created topics (0 = library default: 1 plaintext, 3 otherwise).",
    )
    parser.add_argument(
        "--schema-registry",
        action="store_true",
        help="Register {topic}-value JSON schemas and produce Schema Registry wire-format payloads.",
    )
    parser.add_argument(
        "--flush-timeout",
        type=int,
        default=120,
        help="Seconds to wait for the final flush per file.",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=10_000,
        help="Log progress every N records.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and validate CSVs without connecting to Kafka.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level.",
    )
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    args = build_arg_parser().parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    # The cm_py_lib module reads environment at import time: mirror CLI options.
    os.environ["KAFKA_BOOTSTRAP_SERVERS"] = args.bootstrap_servers
    if args.api_key:
        os.environ["KAFKA_API_KEY"] = args.api_key
    if args.api_secret:
        os.environ["KAFKA_API_SECRET"] = args.api_secret
    if args.security_protocol:
        os.environ["KAFKA_SECURITY_PROTOCOL"] = args.security_protocol
    os.environ["KAFKA_PARTITIONS"] = str(args.partitions)
    if args.replication_factor:
        os.environ["KAFKA_REPLICATION_FACTOR"] = str(args.replication_factor)

    topic_overrides = parse_topics(args.topics)
    sources = [with_topic(s, args, topic_overrides) for s in parse_files(args.files)]
    logger.info(
        "Data dir: %s | bootstrap: %s | files: %s%s",
        args.data_dir,
        args.bootstrap_servers,
        ", ".join(f"{s.name}->{s.topic}" for s in sources),
        " | schema-registry" if args.schema_registry else "",
    )

    if args.dry_run:
        producer = None
        cm = None
    else:
        cm = import_cm_py_lib()
        kafka_config = cm._kafka_client_config()
        for source in sources:
            cm.ensure_topic_exists(kafka_config, source.topic)
            if not args.schema_registry:
                # --schema-registry mode registers the schema itself (KafkaJSONProducer);
                # plain mode still publishes the schema for documentation/consumer contract.
                ensure_schema_registered(cm, pydantic_model_for(source.name), source.topic)

        if args.schema_registry:
            producer = None  # each topic gets its own cm_py_lib producer (below)
        else:
            from confluent_kafka import Producer

            producer = Producer(
                {
                    **kafka_config,
                    "client.id": "airbnb-csv-producer",
                    "acks": "all",
                    "batch.size": 65_536,
                    "linger.ms": 5,
                    "message.timeout.ms": 60_000,
                }
            )

    # Stop gracefully on Ctrl+C: flush what is in flight, then exit.
    def _shutdown(signum, frame):  # noqa: ARG001
        logger.warning("Interrupt received, flushing and exiting...")
        try:
            if producer is not None:
                producer.flush(timeout=args.flush_timeout)
            for kp in sr_producers.values():
                kp.producer.flush(timeout=args.flush_timeout)
        finally:
            sys.exit(130)

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    sr_producers: dict[str, Any] = {}
    all_stats: list[ProduceStats] = []
    try:
        for source in sources:
            if args.schema_registry and not args.dry_run:
                model_class = pydantic_model_for(source.name)
                kp = cm.KafkaJSONProducer(
                    topic_name=source.topic, use_schema_registry=True, model_class=model_class
                )
                sr_producers[source.topic] = kp
                encoder = build_sr_encoder(cm, kp)
                source_producer = kp.producer
            else:
                encoder = None
                source_producer = producer
            all_stats.append(produce_source(source_producer, source, args, encoder))
    finally:
        if producer is not None:
            producer.flush(timeout=args.flush_timeout)
        for kp in sr_producers.values():
            kp.producer.flush(timeout=args.flush_timeout)

    total_records = sum(s.records for s in all_stats)
    total_failed = sum(s.failed + s.in_flight for s in all_stats)
    logger.info(
        "DONE: %d records across %d topics, %d failed/in-flight",
        total_records,
        len(all_stats),
        total_failed,
    )
    return 1 if total_failed else 0


def pydantic_model_for(source_name: str):
    """Pydantic model used for Schema Registry subjects (lazy import)."""
    from pydantic import BaseModel

    class Host(BaseModel):
        host_id: Optional[str] = None
        host_name: Optional[str] = None
        is_superhost: Optional[bool] = None
        created_at: Optional[str] = None
        updated_at: Optional[str] = None

    class Listing(BaseModel):
        listing_id: Optional[str] = None
        listing_url: Optional[str] = None
        listing_name: Optional[str] = None
        room_type: Optional[str] = None
        minimum_nights: Optional[int] = None
        host_id: Optional[str] = None
        price_str: Optional[str] = None
        price: Optional[float] = None
        created_at: Optional[str] = None
        updated_at: Optional[str] = None

    class Review(BaseModel):
        listing_id: Optional[str] = None
        date: Optional[str] = None
        reviewer_name: Optional[str] = None
        comments: Optional[str] = None
        sentiment: Optional[str] = None

    return {"hosts": Host, "listings": Listing, "reviews": Review}[source_name]


if __name__ == "__main__":
    raise SystemExit(main())
