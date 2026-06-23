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
- ``ensure_topic_exists`` — idempotent topic creation helper (also called from
  ``KafkaJSONProducer.__init__``)

Dependencies
------------
- confluent-kafka[schema-registry]>=2.3.0
- pydantic>=2.0.0
- jsonschema>=4.0.0
"""

import json
import os
import random
import time
import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, Optional, Type

import jsonschema
from confluent_kafka import Producer
from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.serialization import MessageField, SerializationContext
from jsonschema import validate
from pydantic import BaseModel
from pydantic_core import PydanticUndefined

# Kafka Configuration from Environment Variables
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9094')
KAFKA_USER = os.getenv('KAFKA_API_KEY', '')
KAFKA_PASSWORD = os.getenv('KAFKA_API_SECRET', '')
KAFKA_SASL_MECHANISM = os.getenv('KAFKA_SASL_MECHANISM', 'SASL')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
DEFAULT_TOPIC = os.getenv('KAFKA_TOPIC', 'raw-rides')
# Schema Registry Configuration
SCHEMA_REGISTRY_URL = os.getenv('SCHEMA_REGISTRY_ENDPOINT', 'http://localhost:8081')
SCHEMA_REGISTRY_USER = os.getenv('SCHEMA_REGISTRY_API_KEY', '')
SCHEMA_REGISTRY_PASSWORD = os.getenv('SCHEMA_REGISTRY_API_SECRET', '')

_SR_SUBJECT_NOT_FOUND = 40401
_SR_INCOMPATIBLE = 40901


def _is_subject_not_found(exc: BaseException) -> bool:
    return isinstance(exc, SchemaRegistryError) and exc.error_code == _SR_SUBJECT_NOT_FOUND


def _is_schema_incompatible(exc: BaseException) -> bool:
    return isinstance(exc, SchemaRegistryError) and exc.error_code == _SR_INCOMPATIBLE


def _schema_is_closed(schema_dict: dict[str, Any]) -> bool:
    """True when the root object schema disallows undeclared properties."""
    return schema_dict.get('type') == 'object' and schema_dict.get('additionalProperties') is False


def _resolve_kafka_security() -> tuple[str, Optional[str]]:
    """Return (security.protocol, sasl.mechanisms) from env, with Confluent Cloud defaults."""
    if not KAFKA_USER:
        return KAFKA_SECURITY_PROTOCOL, None

    protocol = KAFKA_SECURITY_PROTOCOL
    mechanism = KAFKA_SASL_MECHANISM

    # Common mistake: security protocol name placed in KAFKA_SASL_MECHANISM.
    if mechanism in ('SASL_SSL', 'SASL_PLAINTEXT'):
        if not os.getenv('KAFKA_SECURITY_PROTOCOL'):
            protocol = mechanism
        mechanism = 'PLAIN'
    elif mechanism in ('', 'SASL'):
        mechanism = 'PLAIN'

    # Confluent Cloud (and most hosted clusters) require SASL_SSL when API keys are set.
    if protocol in ('', 'PLAINTEXT') and (
        KAFKA_USER or 'confluent.cloud' in KAFKA_BROKERS
    ):
        protocol = 'SASL_SSL'

    return protocol, mechanism


def _kafka_client_config() -> dict[str, str]:
    """Shared broker/auth settings for producer and admin clients."""
    security_protocol, sasl_mechanism = _resolve_kafka_security()
    options: dict[str, str] = {
        'bootstrap.servers': KAFKA_BROKERS,
    }
    if KAFKA_USER and sasl_mechanism:
        options.update({
            'security.protocol': security_protocol,
            'sasl.mechanisms': sasl_mechanism,
            'sasl.username': KAFKA_USER,
            'sasl.password': KAFKA_PASSWORD,
        })
    return options


def _default_replication_factor() -> int:
    if os.getenv('KAFKA_REPLICATION_FACTOR'):
        return int(os.getenv('KAFKA_REPLICATION_FACTOR', '3'))
    protocol, _ = _resolve_kafka_security()
    return 1 if protocol == 'PLAINTEXT' else 3


def _schemas_equivalent(left: dict[str, Any], right: dict[str, Any]) -> bool:
    """Return True when two JSON Schema dicts are structurally identical."""
    return json.dumps(left, sort_keys=True) == json.dumps(right, sort_keys=True)


def _field_default_value(model_class: Type[BaseModel], field_name: str) -> Any:
    """Return the Pydantic default for a model field, or ``PydanticUndefined``."""
    field = model_class.model_fields.get(field_name)
    if field is None:
        return PydanticUndefined
    if field.default_factory is not None:
        return field.default_factory()
    return field.default


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
    model_class: Type[BaseModel],
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


def ensure_topic_exists(kafka_config: dict[str, str], topic_name: str) -> None:
    """Create the Kafka topic when it does not exist."""
    admin = AdminClient(kafka_config)
    try:
        metadata = admin.list_topics(timeout=15)
    except Exception as exc:
        protocol = kafka_config.get('security.protocol', 'PLAINTEXT')
        raise RuntimeError(
            f"Failed to connect to Kafka at {kafka_config.get('bootstrap.servers')!r} "
            f"(security.protocol={protocol}). For Confluent Cloud use "
            "KAFKA_SECURITY_PROTOCOL=SASL_SSL and KAFKA_SASL_MECHANISM=PLAIN."
        ) from exc
    if topic_name in metadata.topics and metadata.topics[topic_name].error is None:
        return

    partitions = int(os.getenv('KAFKA_PARTITIONS', '1'))
    replication_factor = _default_replication_factor()
    futures = admin.create_topics(
        [NewTopic(topic_name, num_partitions=partitions, replication_factor=replication_factor)]
    )
    for name, future in futures.items():
        try:
            future.result(timeout=30)
            print(f"Created Kafka topic '{name}'.")
        except Exception as exc:
            if "TOPIC_ALREADY_EXISTS" in str(exc):
                return
            raise RuntimeError(f"Failed to create topic '{name}': {exc}") from exc


class KafkaJSONProducer:
    """Produce JSON records to Kafka with optional Schema Registry integration.

    On construction:

    1. Ensures ``topic_name`` exists (creates with ``KAFKA_PARTITIONS`` /
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

    def __init__(self, topic_name: str = DEFAULT_TOPIC, use_schema_registry: bool = True, model_class: Type[BaseModel] = None   ):
        self.topic_name = topic_name
        self.use_schema_registry = use_schema_registry
        self.schema_registry_client: Optional[SchemaRegistryClient] = None
        self.cached_schemas: dict[str, dict[str, Any]] = {}
        self.value_serializer: Optional[JSONSerializer] = None

        ensure_topic_exists(_kafka_client_config(), topic_name)
        self.producer = self._create_producer()

        if self.use_schema_registry:
            self.schema_registry_client = self._create_schema_registry_client()
            self.ensure_value_schema(model_class)

    def _create_producer(self) -> Producer:
        """Create and configure Kafka producer with environment-based settings."""
        options = {
            **_kafka_client_config(),
            'delivery.timeout.ms': 15000,
            'request.timeout.ms': 15000,
            'client.id': f'producer-{uuid.uuid4().hex[:8]}',
        }

        print("=== Kafka Producer Configuration ===")
        print(f"Bootstrap servers: {options['bootstrap.servers']}")
        print(f"Security protocol: {options.get('security.protocol', 'PLAINTEXT')}")
        if options.get('sasl.mechanisms'):
            print(f"SASL mechanism: {options['sasl.mechanisms']}")
        print(f"Topic: {self.topic_name}")
        print("===================================")

        return Producer(options)

    def _create_schema_registry_client(self) -> SchemaRegistryClient:
        """Create and configure Schema Registry client."""
        conf = {'url': SCHEMA_REGISTRY_URL}

        if SCHEMA_REGISTRY_USER:
            conf.update({
                'basic.auth.user.info': f'{SCHEMA_REGISTRY_USER}:{SCHEMA_REGISTRY_PASSWORD}',
            })

        print("=== Schema Registry Configuration ===")
        print(f"URL: {conf['url']}")
        print(f"Auth enabled: {bool(SCHEMA_REGISTRY_USER)}")
        print("====================================")

        return SchemaRegistryClient(conf)

    def _value_subject_name(self) -> str:
        return f"{self.topic_name}-value"

    def _build_value_serializer(self, schema_str: str) -> None:
        def to_dict(obj: Any, _ctx: SerializationContext) -> dict[str, Any]:
            if isinstance(obj, BaseModel):
                return obj.model_dump()
            return obj

        self.value_serializer = JSONSerializer(
            schema_str,
            self.schema_registry_client,
            to_dict,
        )

    def _register_and_install_schema(self, schema_dict: dict[str, Any]) -> None:
        """Register a schema version and refresh cache + serializer."""
        subject_name = self._value_subject_name()
        schema_str = json.dumps(schema_dict)
        schema = Schema(schema_str, schema_type="JSON")

        try:
            schema_id = self.schema_registry_client.register_schema(subject_name, schema)
        except SchemaRegistryError as exc:
            if not _is_schema_incompatible(exc):
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
        self.cached_schemas[self.topic_name] = schema_dict
        self._build_value_serializer(schema_str)

    def ensure_value_schema(self, model_class: Type[BaseModel]) -> None:
        """Register or fetch the JSON schema for the topic value subject."""
        if not self.schema_registry_client:
            return

        subject_name = self._value_subject_name()
        try:
            schema_metadata = self.schema_registry_client.get_latest_version(subject_name)
            schema_str = schema_metadata.schema.schema_str
            schema_dict = json.loads(schema_str)
            print(f"Retrieved schema for subject '{subject_name}' from Schema Registry")
        except SchemaRegistryError as exc:
            if not _is_subject_not_found(exc):
                raise
            print(f"Subject '{subject_name}' not found; registering initial schema")
            schema_dict = prepare_json_schema_for_registry(
                model_class.model_json_schema(),
                model_class,
            )
            self._register_and_install_schema(schema_dict)
            return

        self.cached_schemas[self.topic_name] = schema_dict
        self._build_value_serializer(schema_str)

    def _schema_matches_record(
        self,
        record: BaseModel,
        registered_schema: dict[str, Any],
    ) -> bool:
        """Return True when the record model matches the registered schema version."""
        record_schema = type(record).model_json_schema()
        if _schemas_equivalent(record_schema, registered_schema):
            return True
        prepared = prepare_json_schema_for_registry(
            record_schema,
            type(record),
            registered_schema,
        )
        return _schemas_equivalent(prepared, registered_schema)

    def _ensure_schema_for_record(self, record: BaseModel) -> bool:
        """Ensure the registry schema matches the record model, evolving if needed."""
        if not self.schema_registry_client:
            return False

        record_schema = type(record).model_json_schema()
        registered_schema = self._get_schema_for_topic(self.topic_name)

        if registered_schema is not None and self._schema_matches_record(record, registered_schema):
            if not self._validate_against_schema(record.model_dump(), registered_schema):
                print(f"Record validation failed for topic '{self.topic_name}'")
                return False
            return True

        try:
            prepared = prepare_json_schema_for_registry(
                record_schema,
                type(record),
                registered_schema,
            )
            self._register_and_install_schema(prepared)
        except Exception as exc:
            print(
                f"Failed to register evolved schema for topic '{self.topic_name}': {exc}"
            )
            return False

        return True

    def _delivery_report(self, err, msg):
        """Callback for message delivery reports."""
        if err is not None:
            print(f"Message delivery failed: {err}")
        else:
            print(
                f"Message delivered to {msg.topic()} [{msg.partition()}] offset {msg.offset()}"
            )

    def _get_schema_for_topic(self, topic_name: str) -> Optional[Dict[str, Any]]:
        """Fetch JSON schema for a topic from cache or Schema Registry."""
        if not self.use_schema_registry or not self.schema_registry_client:
            return None

        if topic_name in self.cached_schemas:
            return self.cached_schemas[topic_name]

        try:
            subject_name = f"{topic_name}-value"
            schema_metadata = self.schema_registry_client.get_latest_version(subject_name)
            schema_dict = json.loads(schema_metadata.schema.schema_str)
            self.cached_schemas[topic_name] = schema_dict
            print(f"Retrieved schema for topic '{topic_name}' from Schema Registry")
            return schema_dict
        except SchemaRegistryError as exc:
            if _is_subject_not_found(exc):
                return None
            print(f"Could not fetch schema for topic '{topic_name}': {exc}")
            return None

    def _validate_against_schema(self, data: Dict[str, Any], schema: Dict[str, Any]) -> bool:
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

    def send_record(self, message_key, record: BaseModel, key: Optional[str] = None) -> bool:
        """Send a Pydantic model to Kafka with optional SR validation and encoding.

        When Schema Registry is enabled, compares the record's Pydantic JSON schema to
        the latest registered ``{topic}-value`` subject. If they differ, registers a
        new schema version and rebuilds the serializer before producing.

        Args:
            message_key: Kafka message key (stringified).
            record: Payload as a Pydantic ``BaseModel`` instance.
            key: Unused; kept for backward compatibility.

        Returns:
            True if the record was queued for delivery, False on validation or
            serialization error.
        """
        try:
            if self.use_schema_registry:
                if not self._ensure_schema_for_record(record):
                    return False

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
            self.producer.poll(0)
            return True

        except Exception as e:
            print(f"Error sending record: {e}")
            return False


