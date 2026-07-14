"""
Reusable Kafka Avro producer with Schema Registry key and value subjects.

Registers or loads ``{topic}-key`` and ``{topic}-value`` Avro schemas from ``.avsc``
files and produces Confluent wire-format messages.

Optional ``value_schema_references`` registers those Avro files as named Schema Registry
subjects first, then attaches them as ``SchemaReference`` entries on the value schema
(for Avro unions/types that cite records by fully-qualified name).

Shared broker / Schema Registry configuration matches ``kafka_json_producer``.
"""

from __future__ import annotations

import json
import uuid
from pathlib import Path
from typing import Any, Sequence

from confluent_kafka import Producer
from confluent_kafka.schema_registry import Schema, SchemaReference, SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.schema_registry.error import SchemaRegistryError
from confluent_kafka.serialization import MessageField, SerializationContext

from cm_py_lib.kafka_json_producer import (
    SCHEMA_REGISTRY_PASSWORD,
    SCHEMA_REGISTRY_URL,
    SCHEMA_REGISTRY_USER,
    _kafka_client_config,
    ensure_topic_exists,
)

_SR_SUBJECT_NOT_FOUND = 40401


def _identity(obj: dict[str, Any], _ctx: SerializationContext) -> dict[str, Any]:
    return obj


def _avro_fqn(schema_path: Path) -> str:
    """Return ``namespace.name`` (or ``name``) from an Avro record schema file."""
    payload = json.loads(schema_path.read_text(encoding="utf-8"))
    name = payload["name"]
    namespace = payload.get("namespace")
    return f"{namespace}.{name}" if namespace else name


class KafkaAvroProducer:
    """Produce Avro-encoded key/value records to Kafka via Schema Registry."""

    def __init__(
        self,
        topic_name: str,
        key_schema_path: Path | str,
        value_schema_path: Path | str,
        *,
        value_schema_references: Sequence[Path | str] | None = None,
        use_schema_registry: bool = True,
    ) -> None:
        self.topic_name = topic_name
        self.key_schema_path = Path(key_schema_path)
        self.value_schema_path = Path(value_schema_path)
        self.value_schema_references = [
            Path(p) for p in (value_schema_references or ())
        ]
        self.use_schema_registry = use_schema_registry
        self.schema_registry_client: SchemaRegistryClient | None = None
        self.key_serializer: AvroSerializer | None = None
        self.value_serializer: AvroSerializer | None = None

        ensure_topic_exists(_kafka_client_config(), topic_name)
        self.producer = Producer(
            {
                **_kafka_client_config(),
                "delivery.timeout.ms": 15000,
                "request.timeout.ms": 15000,
                "client.id": f"avro-producer-{uuid.uuid4().hex[:8]}",
            }
        )

        if self.use_schema_registry:
            self.schema_registry_client = self._create_schema_registry_client()
            self._install_serializers()

    def _create_schema_registry_client(self) -> SchemaRegistryClient:
        conf: dict[str, str] = {"url": SCHEMA_REGISTRY_URL}
        if SCHEMA_REGISTRY_USER:
            conf["basic.auth.user.info"] = (
                f"{SCHEMA_REGISTRY_USER}:{SCHEMA_REGISTRY_PASSWORD}"
            )
        return SchemaRegistryClient(conf)

    def _read_schema(self, path: Path) -> str:
        if not path.is_file():
            raise FileNotFoundError(f"Avro schema not found: {path}")
        return path.read_text(encoding="utf-8")

    def _ensure_subject(
        self,
        subject_name: str,
        schema_path: Path,
        *,
        references: list[SchemaReference] | None = None,
    ) -> Schema:
        """Load or register a subject; return the Schema (including any references)."""
        assert self.schema_registry_client is not None
        try:
            metadata = self.schema_registry_client.get_latest_version(subject_name)
            return metadata.schema
        except SchemaRegistryError as exc:
            if exc.error_code != _SR_SUBJECT_NOT_FOUND:
                raise
        schema_str = self._read_schema(schema_path)
        schema = Schema(schema_str, schema_type="AVRO", references=references or [])
        schema_id = self.schema_registry_client.register_schema(subject_name, schema)
        print(f"Registered Avro schema id {schema_id} for subject '{subject_name}'")
        return schema

    def _build_value_references(self) -> list[SchemaReference]:
        assert self.schema_registry_client is not None
        refs: list[SchemaReference] = []
        for path in self.value_schema_references:
            fqn = _avro_fqn(path)
            # Register each referenced record under its FQN as the subject name.
            self._ensure_subject(fqn, path)
            version = self.schema_registry_client.get_latest_version(fqn).version
            refs.append(SchemaReference(name=fqn, subject=fqn, version=version))
            print(f"Schema reference ready: name={fqn} subject={fqn} version={version}")
        return refs

    def _install_serializers(self) -> None:
        assert self.schema_registry_client is not None
        key_schema = self._ensure_subject(
            f"{self.topic_name}-key", self.key_schema_path
        )
        value_refs = self._build_value_references()
        value_schema = self._ensure_subject(
            f"{self.topic_name}-value",
            self.value_schema_path,
            references=value_refs or None,
        )
        self.key_serializer = AvroSerializer(
            self.schema_registry_client, key_schema, _identity
        )
        self.value_serializer = AvroSerializer(
            self.schema_registry_client, value_schema, _identity
        )

    def _delivery_report(self, err, msg) -> None:
        if err is not None:
            print(f"Message delivery failed: {err}")
        else:
            print(
                f"Message delivered to {msg.topic()} "
                f"[{msg.partition()}] offset {msg.offset()}"
            )

    def flush_and_close(self) -> None:
        print("Flushing pending messages...")
        self.producer.flush()
        print("Producer closed successfully")

    def send_record(self, key: dict[str, Any], value: dict[str, Any]) -> bool:
        """Send an Avro key/value pair. Dict keys must match the ``.avsc`` fields."""
        try:
            if self.use_schema_registry:
                if self.key_serializer is None or self.value_serializer is None:
                    print("Avro serializers are not initialized")
                    return False
                key_bytes = self.key_serializer(
                    key, SerializationContext(self.topic_name, MessageField.KEY)
                )
                value_bytes = self.value_serializer(
                    value, SerializationContext(self.topic_name, MessageField.VALUE)
                )
            else:
                key_bytes = json.dumps(key).encode("utf-8")
                value_bytes = json.dumps(value).encode("utf-8")

            self.producer.produce(
                self.topic_name,
                key=key_bytes,
                value=value_bytes,
                callback=self._delivery_report,
            )
            self.producer.poll(0)
            return True
        except Exception as exc:
            print(f"Error sending record: {exc}")
            return False
