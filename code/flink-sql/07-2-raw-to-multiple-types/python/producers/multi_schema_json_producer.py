"""Multi-schema JSON Kafka producer (RecordNameStrategy subjects).

Registers each Pydantic model's JSON Schema under its ``title`` subject and
produces Confluent wire-format values via ``JSONSerializer`` with
``record_subject_name_strategy``. 
"""

from __future__ import annotations

import json
import uuid
from typing import Any, Type

from confluent_kafka import Producer
from confluent_kafka.schema_registry import (
    Schema,
    SchemaRegistryClient,
    record_subject_name_strategy,
)
from confluent_kafka.schema_registry.error import SchemaRegistryError
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.serialization import MessageField, SerializationContext
from pydantic import BaseModel

from cm_py_lib.kafka_json_producer import (
    SCHEMA_REGISTRY_PASSWORD,
    SCHEMA_REGISTRY_URL,
    SCHEMA_REGISTRY_USER,
    _is_schema_incompatible,
    _is_subject_not_found,
    _kafka_client_config,
    ensure_topic_exists,
    prepare_json_schema_for_registry,
)


class MultiSchemaJsonProducer:
    """Produce records of several JSON Schema types to one topic."""

    def __init__(
        self,
        topic_name: str,
        model_classes: list[Type[BaseModel]],
    ) -> None:
        if not model_classes:
            raise ValueError("model_classes must not be empty")

        self.topic_name = topic_name
        self._serializers: dict[Type[BaseModel], JSONSerializer] = {}
        self._subjects: dict[Type[BaseModel], str] = {}

        ensure_topic_exists(_kafka_client_config(), topic_name)
        self.producer = Producer(
            {
                **_kafka_client_config(),
                "delivery.timeout.ms": 15000,
                "request.timeout.ms": 15000,
                "client.id": f"multi-json-producer-{uuid.uuid4().hex[:8]}",
            }
        )
        self.schema_registry_client = self._create_schema_registry_client()

        for model_class in model_classes:
            subject, serializer = self._register_model(model_class)
            self._subjects[model_class] = subject
            self._serializers[model_class] = serializer
            print(f"Ready: subject={subject} model={model_class.__name__}")

    def _create_schema_registry_client(self) -> SchemaRegistryClient:
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

    def _schema_title(self, model_class: Type[BaseModel], schema_dict: dict[str, Any]) -> str:
        title = schema_dict.get("title")
        if isinstance(title, str) and title.strip():
            return title.strip()
        raise ValueError(
            f"{model_class.__name__} JSON schema must set title "
            "(RecordNameStrategy subject name)"
        )

    def _build_serializer(self, schema_str: str) -> JSONSerializer:
        def to_dict(obj: Any, _ctx: SerializationContext) -> dict[str, Any]:
            if isinstance(obj, BaseModel):
                return obj.model_dump()
            return obj

        return JSONSerializer(
            schema_str,
            self.schema_registry_client,
            to_dict,
            conf={"subject.name.strategy": record_subject_name_strategy},
        )

    def _register_schema(self, subject_name: str, schema_dict: dict[str, Any]) -> int:
        schema_str = json.dumps(schema_dict)
        schema = Schema(schema_str, schema_type="JSON")
        try:
            schema_id = self.schema_registry_client.register_schema(subject_name, schema)
        except SchemaRegistryError as exc:
            if not _is_schema_incompatible(exc):
                raise
            print(
                f"BACKWARD compatibility rejected for '{subject_name}'; "
                "retrying with NONE"
            )
            prior_compat: str | None = None
            try:
                prior_compat = self.schema_registry_client.get_compatibility(subject_name)
            except SchemaRegistryError:
                pass
            self.schema_registry_client.set_compatibility(subject_name, "NONE")
            try:
                schema_id = self.schema_registry_client.register_schema(
                    subject_name, schema
                )
            finally:
                if prior_compat:
                    self.schema_registry_client.set_compatibility(
                        subject_name, prior_compat
                    )
        print(f"Registered schema id {schema_id} for subject '{subject_name}'")
        return schema_id

    def _register_model(
        self, model_class: Type[BaseModel]
    ) -> tuple[str, JSONSerializer]:
        prepared = prepare_json_schema_for_registry(
            model_class.model_json_schema(),
            model_class,
        )
        subject_name = self._schema_title(model_class, prepared)
        # Keep title for RecordNameStrategy after prepare_json_schema_for_registry.
        prepared["title"] = subject_name

        try:
            latest = self.schema_registry_client.get_latest_version(subject_name)
            schema_str = latest.schema.schema_str
            print(f"Retrieved schema for subject '{subject_name}'")
        except SchemaRegistryError as exc:
            if not _is_subject_not_found(exc):
                raise
            print(f"Subject '{subject_name}' not found; registering")
            self._register_schema(subject_name, prepared)
            schema_str = json.dumps(prepared)

        return subject_name, self._build_serializer(schema_str)

    def _delivery_report(self, err, msg) -> None:
        if err is not None:
            print(f"Message delivery failed: {err}")
        else:
            print(
                f"Message delivered to {msg.topic()} [{msg.partition()}] "
                f"offset {msg.offset()}"
            )

    def send_record(self, message_key: str, record: BaseModel) -> bool:
        model_class = type(record)
        serializer = self._serializers.get(model_class)
        if serializer is None:
            print(f"No serializer registered for {model_class.__name__}")
            return False
        try:
            value = serializer(
                record,
                SerializationContext(self.topic_name, MessageField.VALUE),
            )
            self.producer.produce(
                self.topic_name,
                key=str(message_key),
                value=value,
                callback=self._delivery_report,
            )
            self.producer.poll(0)
            return True
        except Exception as exc:
            print(f"Error sending record: {exc}")
            return False

    def flush_and_close(self) -> None:
        print("Flushing pending messages...")
        self.producer.flush()
        print("Producer closed successfully")

    def subjects(self) -> dict[str, str]:
        """Map model class name → Schema Registry subject."""
        return {cls.__name__: subj for cls, subj in self._subjects.items()}
