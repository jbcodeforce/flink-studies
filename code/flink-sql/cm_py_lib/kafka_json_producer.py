"""
Reusable Kafka JSON producer with topic and Schema Registry bootstrap.

This module is shared by Flink SQL demo producers (e.g.
``13-materialized-table/rides_producer.py``). It wraps ``confluent-kafka`` to:

- Create the target topic if it does not exist (``AdminClient``)
- Register or fetch a JSON Schema Registry subject ``{topic}-value`` from a
  Pydantic model
- Validate records client-side with ``jsonschema``
- Produce Schema Registry wire-format payloads via ``JSONSerializer``
- **Auto-evolve** the registry subject when a record's Pydantic schema differs from
  the latest registered version (registers a new schema version and rebuilds the
  serializer). New optional fields must declare a Pydantic ``Field(default=...)``.
  First registration closes the object model (``additionalProperties: false``).
  If BACKWARD compatibility rejects an evolution (common with legacy open v1
  schemas), registration retries with subject compatibility ``NONE``.

  When recreating a Kafka topic, delete the orphaned Schema Registry subject
  (``{topic}-value``) too, or the producer will load the old schema version.

Works against local Kafka (PLAINTEXT) and Confluent Cloud (SASL_SSL + API keys).
When ``KAFKA_API_KEY`` is set, security defaults to ``SASL_SSL`` / ``PLAIN`` even
if ``KAFKA_SECURITY_PROTOCOL`` is unset.

Environment variables
---------------------
Kafka:

- ``KAFKA_BOOTSTRAP_SERVERS`` — broker list (default: ``localhost:9094``)
- ``KAFKA_TOPIC`` — default topic name (default: ``raw-rides``)
- ``KAFKA_API_KEY`` / ``KAFKA_API_SECRET`` — SASL credentials (optional locally)
- ``KAFKA_SECURITY_PROTOCOL`` — e.g. ``PLAINTEXT``, ``SASL_SSL`` (auto-inferred for CC)
- ``KAFKA_SASL_MECHANISM`` — e.g. ``PLAIN`` (not ``SASL_SSL``; that is a protocol)
- ``KAFKA_PARTITIONS`` — partitions when creating a topic (default: ``1``)
- ``KAFKA_REPLICATION_FACTOR`` — RF when creating a topic (default: ``1`` local,
  ``3`` when not PLAINTEXT)

Schema Registry:

- ``SCHEMA_REGISTRY_ENDPOINT`` — registry URL (default: ``http://localhost:8081``)
- ``SCHEMA_REGISTRY_API_KEY`` / ``SCHEMA_REGISTRY_API_SECRET`` — basic auth (optional)

Load credentials before running, for example::

    source code/flink-sql/set_env.sh

Usage
-----
Minimal producer script::

    from pydantic import BaseModel
    from cm_py_lib.kafka_json_producer import KafkaJSONProducer

    class Ride(BaseModel):
        ride_id: str
        driver_id: str
        # ...

    producer = KafkaJSONProducer(
        topic_name="raw-rides",
        use_schema_registry=True,
        model_class=Ride,
    )
    record = Ride(ride_id="1", driver_id="d1", ...)
    producer.send_record(record.ride_id, record)
    producer.flush_and_close()

Set ``use_schema_registry=False`` to send plain JSON without SR encoding (topic is
still created if missing).

Public API
----------
- ``KafkaJSONProducer`` — main producer class


Dependencies
------------
- confluent-kafka[schema-registry]>=2.3.0
- pydantic>=2.0.0
- jsonschema>=4.0.0
"""

import json
import uuid
from typing import Any

import jsonschema
from confluent_kafka import Producer
from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.serialization import MessageField, SerializationContext
from jsonschema import validate
from pydantic import BaseModel
from pydantic_core import PydanticUndefined, to_jsonable_python

from cm_py_lib.schema_registry import (
    create_schema_registry_client,
    value_subject_name,
    is_subject_not_found,
    get_schema_for_topic,
    is_schema_incompatible
)
from cm_py_lib.config import (
    DEFAULT_TOPIC,
    get_kafka_client_config,
    ensure_topic_exists,
    LOGGER
)


def _schema_is_closed(schema_dict: dict[str, Any]) -> bool:
    """True when the root object schema disallows undeclared properties."""
    return schema_dict.get('type') == 'object' and schema_dict.get('additionalProperties') is False

def _field_default_value(model_class: BaseModel, field_name: str) -> Any:
    """Return the Pydantic default for a model field, or ``PydanticUndefined``."""
    field = model_class.model_fields.get(field_name)
    if field is None:
        return PydanticUndefined
    val = field.get_default(call_default_factory=True)
    if val is PydanticUndefined:
        return PydanticUndefined
    # Converts objects (datetime, UUID, Enum, etc.) to JSON Schema compatible values
    return to_jsonable_python(val)


def _close_object_schemas(node: Any) -> None:
    """Set additionalProperties=false on object schemas (required by Confluent SR)."""
    if isinstance(node, dict):
        if node.get('type') == 'object':
            node['additionalProperties'] = False
        for value in node.values():
            _close_object_schemas(value)
    elif isinstance(node, list):
        for item in node:
            _close_object_schemas(item)


def prepare_json_schema_for_registry(
    schema_dict: dict[str, Any],
    model_class: BaseModel,
    prior_schema: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Normalize a Pydantic JSON Schema for Confluent SR registration.

    - **First registration** (no prior): closes the object model
      (``additionalProperties: false``) so later BACKWARD evolution can add
      optional fields with defaults.
    - **Evolution from a closed prior**: keeps the model closed; new properties
      must have a Pydantic ``Field(default=...)``.
    - **Evolution from an open prior** (legacy v1 without
      ``additionalProperties``): keeps the model open to avoid
      ``ADDITIONAL_PROPERTIES_REMOVED``; registration may require NONE
      compatibility (handled in ``_register_and_install_schema``).
    """
    schema = json.loads(json.dumps(schema_dict))

    if prior_schema is None or _schema_is_closed(prior_schema):
        _close_object_schemas(schema)

    if prior_schema is not None:
        properties = schema.get('properties', {})
        prior_properties = prior_schema.get('properties', {})
        required = set(schema.get('required', []))

        for name, prop in properties.items():
            if name in prior_properties:
                continue
            required.discard(name)
            if 'default' in prop:
                continue
            default = _field_default_value(model_class, name)
            if default is PydanticUndefined:
                raise ValueError(
                    f"Cannot evolve schema: new field '{name}' on {model_class.__name__} "
                    "has no default. Use Field(default=...) for BACKWARD compatibility."
                )
            prop['default'] = default

        if required:
            schema['required'] = sorted(required)
        else:
            schema.pop('required', None)

    return schema


class KafkaJSONProducer:
    """Produce JSON records to Kafka with optional Schema Registry integration.

    On construction:

    1. Ensures ``topic_name`` exists (creates it with ``KAFKA_PARTITIONS`` /
       ``KAFKA_REPLICATION_FACTOR`` when missing).
    2. When ``use_schema_registry`` is True, registers or loads ``{topic}-value``
       from ``model_class.model_json_schema()`` and configures ``JSONSerializer``.

    Args:
        topic_name: Kafka topic to produce to.
        use_schema_registry: If True, register/fetch JSON schema and encode values
            with Schema Registry wire format.
        model_class: Pydantic model used to derive the value schema when the
            subject does not exist yet. Required when ``use_schema_registry`` is True.
    """

    def __init__(
        self,
        topic_name: str = DEFAULT_TOPIC,
        use_schema_registry: bool = True,
        model_class: BaseModel | None = None,
    ):
        self.topic_name = topic_name
        self.use_schema_registry = use_schema_registry
        self.schema_registry_client: SchemaRegistryClient | None = None
        self.cached_schemas: dict[str, dict[str, Any]| None] = {}
        self.key_serializer: JSONSerializer | None  = None
        self.value_serializer: JSONSerializer | None  = None

        ensure_topic_exists(get_kafka_client_config(), topic_name)
        self.producer = self._create_producer()

        if self.use_schema_registry:
            self.schema_registry_client = create_schema_registry_client()
            if model_class is not None:
                self.ensure_value_schema(model_class)

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


    def _build_value_serializer(self, schema_str: str) -> None:
        def to_dict(obj: Any, _ctx: SerializationContext) -> dict[str, Any]:
            if obj is None:
                return None
            return obj.model_dump(mode='json')
            
        self.value_serializer = JSONSerializer(
            schema_str=schema_str,
            schema_registry_client=self.schema_registry_client,
            to_dict = to_dict
        )

    def _register_and_install_schema(self, schema_dict: dict[str, Any]) -> None:
        """Register a schema version and refresh cache + serializer."""
        subject_name = value_subject_name(self.topic_name)
        schema_str = json.dumps(schema_dict)
        schema = Schema(schema_str, schema_type="JSON")

        try:
            schema_id = self.schema_registry_client.register_schema(subject_name, schema)
        except SchemaRegistryError as exc:
            if not is_schema_incompatible(exc):
                raise
            print(
                f"BACKWARD compatibility rejected for '{subject_name}' "
                f"(often caused by a legacy open v1 schema); retrying with NONE"
            )
            prior_compat: str | None = None
            try:
                prior_compat = self.schema_registry_client.get_compatibility(subject_name)
            except SchemaRegistryError:
                pass
            self.schema_registry_client.set_compatibility(subject_name, 'NONE')
            try:
                schema_id = self.schema_registry_client.register_schema(subject_name, schema)
            finally:
                if prior_compat:
                    self.schema_registry_client.set_compatibility(subject_name, prior_compat)

        print(f"Registered schema version {schema_id} for subject '{subject_name}'")


    def ensure_value_schema(self, model_class: BaseModel) -> None:
        """Register or fetch the JSON schema for the topic value subject."""
        try:
            schema_dict=get_schema_for_topic(self.topic_name)
        except SchemaRegistryError as exc:
            if not is_subject_not_found(exc):
                raise
            print(f"Subject for '{self.topic_name}' not found; registering initial schema")
            schema_dict = prepare_json_schema_for_registry(
                model_class.model_json_schema(),
                model_class,
            )
            self._register_and_install_schema(schema_dict)
        self.cached_schemas[self.topic_name] = schema_dict
        schema_str = json.dumps(schema_dict)
        self._build_value_serializer(schema_str)


    def _validate_against_schema(self, data: dict[str, Any], schema: dict[str, Any]) -> bool:
        """Validate data against JSON schema."""
        try:
            validate(instance=data, schema=schema)
            return True
        except jsonschema.exceptions.ValidationError as e:
            print(f"Schema validation failed: {e.message}")
            print(f"Failed at path: {' -> '.join(str(p) for p in e.absolute_path)}")
            return False
        except Exception as e:
            print(f"Unexpected validation error: {e}")
            return False

    def flush_and_close(self):
        """Flush pending messages and close producer."""
        print("Flushing pending messages...")
        self.producer.flush()
        print("Producer closed successfully")

    def _delivery_report(self, err, msg):
        """Callback for message delivery reports."""
        if err is not None:
            print(f"Message delivery failed: {err}")
        else:
            print(
                f"Message delivered to {msg.topic()} [{msg.partition()}] offset {msg.offset()}"
            )


    def send_record(self, message_key, record: BaseModel) -> bool:
        """Send a Pydantic model to Kafka with optional SR validation and encoding.

        When Schema Registry is enabled, compares the record's Pydantic JSON schema to
        the latest registered ``{topic}-value`` subject. If they differ, registers a
        new schema version and rebuilds the serializer before producing.

        Args:
            message_key: Kafka message key (stringified).
            record: Payload as a Pydantic ``BaseModel`` instance.

        Returns:
            True if the record was queued for delivery, False on validation or
            serialization error.
        """
        try:
            if self.use_schema_registry:
                if self.value_serializer is None:
                    print("Schema Registry serializer is not initialized")
                    return False

                value = self.value_serializer(
                    record,
                    SerializationContext(self.topic_name, MessageField.VALUE),
                )
            else:
                value = record.model_dump_json()

            self.producer.produce(
                self.topic_name,
                key=str(message_key),
                value=value,
                callback=self._delivery_report,
            )
            rc = self.producer.flush()
            print(rc)
            return True

        except Exception as e:
            print(f"Error sending record: {e}")
            return False


