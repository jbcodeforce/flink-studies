"""Multi-schema JSON Kafka producer (TopicNameStrategy + compatibility NONE).

Registers three incompatible JSON Schema versions under a single
``{topic}-value`` subject (compatibility left at NONE) and produces Confluent
wire-format values via ``JSONSerializer`` with ``use.schema.id`` pinned per
event type so each message embeds the correct schema id.
"""

from __future__ import annotations

import json
import uuid
from typing import Any, Type

from confluent_kafka import Producer
from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
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
    """Produce several JSON Schema shapes to one TopicNameStrategy subject."""

    def __init__(
        self,
        topic_name: str,
        model_classes: list[Type[BaseModel]],
    ) -> None:
        if not model_classes:
            raise ValueError("model_classes must not be empty")

        self.topic_name = topic_name
        self.subject_name = f"{topic_name}-value"
        self._serializers: dict[Type[BaseModel], JSONSerializer] = {}
        self._schema_ids: dict[Type[BaseModel], int] = {}

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
        self._ensure_compatibility_none()

        for model_class in model_classes:
            schema_id, serializer = self._register_model(model_class)
            self._schema_ids[model_class] = schema_id
            self._serializers[model_class] = serializer
            print(
                f"Ready: subject={self.subject_name} "
                f"model={model_class.__name__} schema_id={schema_id}"
            )

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

    def _ensure_compatibility_none(self) -> None:
        """Force NONE so incompatible envelope schemas can share one subject."""
        prior: str | None
        try:
            prior = self.schema_registry_client.get_compatibility(self.subject_name)
        except SchemaRegistryError as exc:
            # 40401: subject missing. 40408: subject exists but no subject-level
            # compatibility (inherits global) — common after soft-delete/recreate.
            code = getattr(exc, "error_code", None)
            if _is_subject_not_found(exc) or code in (40401, 40408):
                prior = None
                print(
                    f"No subject-level compatibility for '{self.subject_name}' "
                    f"(SR code {code}); will set NONE"
                )
            else:
                raise

        if prior == "NONE":
            print(f"Compatibility already NONE on '{self.subject_name}'")
            return

        try:
            self.schema_registry_client.set_compatibility(self.subject_name, "NONE")
        except SchemaRegistryError as exc:
            if _is_subject_not_found(exc) or getattr(exc, "error_code", None) == 40401:
                print(
                    f"Subject '{self.subject_name}' not found yet; "
                    "will set NONE after first registration"
                )
                return
            raise
        print(
            f"Set compatibility NONE on '{self.subject_name}' "
            f"(was {prior!r}; left at NONE for this demo)"
        )

    def _build_serializer(self, schema_str: str, schema_id: int) -> JSONSerializer:
        def to_dict(obj: Any, _ctx: SerializationContext) -> dict[str, Any]:
            if isinstance(obj, BaseModel):
                return obj.model_dump()
            return obj

        # Default subject.name.strategy is TopicNameStrategy ({topic}-value).
        # Pin schema id so DeviceSwap/Subscription/DeviceClose do not all use latest.
        return JSONSerializer(
            schema_str,
            self.schema_registry_client,
            to_dict,
            conf={
                "auto.register.schemas": False,
                "use.schema.id": schema_id,
            },
        )

    def _register_schema(self, schema_dict: dict[str, Any]) -> int:
        schema_str = json.dumps(schema_dict)
        schema = Schema(schema_str, schema_type="JSON")
        try:
            schema_id = self.schema_registry_client.register_schema(
                self.subject_name, schema
            )
        except SchemaRegistryError as exc:
            if not _is_schema_incompatible(exc):
                raise
            # Should be rare after _ensure_compatibility_none; retry once.
            self.schema_registry_client.set_compatibility(self.subject_name, "NONE")
            schema_id = self.schema_registry_client.register_schema(
                self.subject_name, schema
            )
        print(
            f"Registered schema id {schema_id} for subject '{self.subject_name}' "
            f"(title={schema_dict.get('title')!r})"
        )
        # Keep NONE for subsequent incompatible versions (demo teaching point).
        self.schema_registry_client.set_compatibility(self.subject_name, "NONE")
        return schema_id

    def _register_model(
        self, model_class: Type[BaseModel]
    ) -> tuple[int, JSONSerializer]:
        prepared = prepare_json_schema_for_registry(
            model_class.model_json_schema(),
            model_class,
        )
        # Distinct title for SR UI / logs (subject remains {topic}-value).
        title = prepared.get("title") or model_class.__name__
        prepared["title"] = title

        schema_id = self._register_schema(prepared)
        schema_str = json.dumps(prepared)
        return schema_id, self._build_serializer(schema_str, schema_id)

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

    def schema_ids(self) -> dict[str, int]:
        """Map model class name → Schema Registry schema id."""
        return {cls.__name__: sid for cls, sid in self._schema_ids.items()}
