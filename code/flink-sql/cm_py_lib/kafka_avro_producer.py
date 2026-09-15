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
import py_avro_schema as pas
import uuid
from pathlib import Path
from typing import Any

from confluent_kafka import Producer
from confluent_kafka.schema_registry import Schema, SchemaReference, SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.schema_registry.error import SchemaRegistryError
from confluent_kafka.serialization import MessageField, SerializationContext

from cm_py_lib.config import (
    get_kafka_client_config,
    get_schema_registry_config,
    ensure_topic_exists,
    LOGGER
)

from cm_py_lib.schema_registry import (
    create_schema_registry_client,
)


def _identity(obj: dict[str, Any], _ctx: SerializationContext) -> dict[str, Any]:
    return obj


def _avro_fqn(schema_path: Path) -> str:
    """Return ``namespace.name`` (or ``name``) from an Avro record schema file."""
    payload = json.loads(schema_path.read_text(encoding="utf-8"))
    name = payload["name"]
    namespace = payload.get("namespace")
    return f"{namespace}.{name}" if namespace else name

def pydantic_to_dict(obj: BaseModel, ctx: SerializationContext) -> dict:
    if obj is None:
        return None
    return obj.model_dump(mode='python')

class KafkaAvroProducer:
    """Produce Avro-encoded key/value records to Kafka via Schema Registry."""

    def __init__(
        self,
        topic_name: str,
        use_schema_registry: bool = True,
    ) -> None:
        self.topic_name = topic_name
        self.use_schema_registry = use_schema_registry
        self.schema_registry_client: SchemaRegistryClient | None = None
   
        kafka_cfg = get_kafka_client_config()
        ensure_topic_exists(kafka_cfg, topic_name)
        self.producer = self._create_producer()
        if self.use_schema_registry:
            self.schema_registry_client = create_schema_registry_client()


    def specify_models_from_paths(
            self,
            key_schema_path: Path,
            value_schema_path: Path):
        key_schema_str = self._read_schema(key_schema_path)
        value_schema_str =  self._read_schema(value_schema_path)
        self._install_serializers(key_schema_str, value_schema_str)

    def specify_models_from_objects(
        self,
        key: BaseModel,
        value: BaseModel): 
        key_schema_str = pas.generate(key).decode("utf-8")
        value_schema_str = pas.generate(value).decode("utf-8")
        print(f"key: {key_schema_str} - value: {value_schema_str}")
        self._install_serializers(key_schema_str, value_schema_str)

    def _install_serializers(self, key_schema_str: str, value_schema_str: str) -> None:
        self.key_serializer = AvroSerializer(
            schema_registry_client=self.schema_registry_client, 
            schema_str=key_schema_str,
            to_dict=pydantic_to_dict
        )
        self.value_serializer = AvroSerializer(
            schema_registry_client=self.schema_registry_client, 
            schema_str=value_schema_str,
            to_dict=pydantic_to_dict
        )
    
    def _create_producer(self) -> Producer:
        """Create and configure Kafka producer with environment-based settings."""
        options = {
            **get_kafka_client_config(),
            'delivery.timeout.ms': 15000,
            'request.timeout.ms': 15000,
            'client.id': f'producer-{uuid.uuid4().hex[:8]}',
        }

        LOGGER.info("=== Kafka Producer Configuration ===")
        LOGGER.info(f"Bootstrap servers: {options['bootstrap.servers']}")
        LOGGER.info(f"Security protocol: {options.get('security.protocol', 'PLAINTEXT')}")
        if options.get('sasl.mechanisms'):
            LOGGER.info(f"SASL mechanism: {options['sasl.mechanisms']}")
        LOGGER.info(f"Topic: {self.topic_name}")
        LOGGER.info("===================================")
        return Producer(options)


    def _read_schema(self, path: Path) -> str:
        if not path.is_file():
            raise FileNotFoundError(f"Avro schema not found: {path}")
        return path.read_text(encoding="utf-8")

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

    def send_record(self, current_key: BaseModel, current_value: BaseModel) -> bool:
        """Send an Avro key/value pair. Dict keys must match the ``.avsc`` fields."""
        try:
            key_bytes = self.key_serializer(
                current_key, 
                SerializationContext(self.topic_name, 
                MessageField.KEY)
            )
            value_bytes = self.value_serializer(
                current_value, 
                SerializationContext(self.topic_name, 
                MessageField.VALUE)
            )

            self.producer.produce(
                self.topic_name,
                key=key_bytes,
                value=value_bytes,
                callback=self._delivery_report,
            )
            self.producer.flush()
            return True
        except Exception as exc:
            print(f"Error sending record: {exc}")
            return False
