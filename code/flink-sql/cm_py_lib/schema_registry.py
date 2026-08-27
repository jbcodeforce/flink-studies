"""
Reusable Schema Registry helpers: fetch schemas and convert them to dbt YAML.

Shared by any script in the repo that needs to inspect Confluent Schema Registry
subjects and produce dbt column definitions.

Three independent layers (each importable on its own):

1. ``SchemaFetcher``   — thin auth wrapper around SchemaRegistryClient
2. ``schema_to_columns`` — pure function: schema dict → list[ColumnSpec]
3. ``render_sources_yaml`` / ``render_model_yaml`` — pure YAML renderers

Environment variables (same names as kafka_json_producer):

- ``SCHEMA_REGISTRY_ENDPOINT`` / ``SCHEMA_REGISTRY_URL`` — registry URL
- ``SCHEMA_REGISTRY_API_KEY`` / ``SCHEMA_REGISTRY_USER`` — basic-auth key
- ``SCHEMA_REGISTRY_API_SECRET`` / ``SCHEMA_REGISTRY_PASSWORD`` — basic-auth secret

Usage::

    from cm_py_lib.schema_registry import SchemaFetcher, schema_to_columns, render_sources_yaml

    fetcher = SchemaFetcher()                                    # reads env vars
    schema, schema_type = fetcher.fetch("raw_hosts-value")
    columns = schema_to_columns(schema, schema_type)
    print(render_sources_yaml("raw_hosts", "j9r-kafka", columns))
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

import yaml
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError

# Re-use the env-var constants already resolved by kafka_json_producer so
# credentials only need to be set in one place (same pattern as
# kafka_avro_producer.py).
from cm_py_lib.kafka_json_producer import (
    SCHEMA_REGISTRY_PASSWORD,
    SCHEMA_REGISTRY_URL,
    SCHEMA_REGISTRY_USER,
)


# ── Schema Registry access ────────────────────────────────────────────────────

class SchemaFetcher:
    """Fetch a schema from Confluent Schema Registry by subject name.

    Credentials are resolved in priority order:
      1. Constructor arguments (``url``, ``key``, ``secret``)
      2. Environment variables (via kafka_json_producer module-level constants)

    Args:
        url:    Schema Registry base URL.  Overrides ``SCHEMA_REGISTRY_ENDPOINT``.
        key:    API key for basic auth.    Overrides ``SCHEMA_REGISTRY_API_KEY``.
        secret: API secret for basic auth. Overrides ``SCHEMA_REGISTRY_API_SECRET``.
    """

    def __init__(
        self,
        url: str | None = None,
        key: str | None = None,
        secret: str | None = None,
    ) -> None:
        effective_url = url or SCHEMA_REGISTRY_URL
        effective_key = key or SCHEMA_REGISTRY_USER
        effective_secret = secret or SCHEMA_REGISTRY_PASSWORD

        if not effective_url:
            raise ValueError(
                "Schema Registry URL is required. Set SCHEMA_REGISTRY_ENDPOINT "
                "or pass --sr-url."
            )

        conf: dict[str, str] = {"url": effective_url}
        if effective_key:
            conf["basic.auth.user.info"] = f"{effective_key}:{effective_secret}"

        self._client = SchemaRegistryClient(conf)

    def fetch(self, subject: str) -> tuple[dict[str, Any], str]:
        """Return ``(schema_dict, schema_type)`` for the latest version of *subject*.

        *schema_type* is one of ``"JSON"``, ``"AVRO"``, or ``"PROTOBUF"``.

        Raises:
            SchemaRegistryError: if the subject does not exist or the request fails.
        """
        try:
            metadata = self._client.get_latest_version(subject)
        except SchemaRegistryError as exc:
            raise SchemaRegistryError(
                exc.error_code,
                f"Subject '{subject}' not found or SR unreachable: {exc}",
            ) from exc

        schema_type: str = metadata.schema.schema_type or "JSON"
        schema_dict: dict[str, Any] = json.loads(metadata.schema.schema_str)
        return schema_dict, schema_type


# ── Type mapping tables ───────────────────────────────────────────────────────

# JSON Schema type (and optional format) → Flink / dbt type.
# Keyed as "type" or "type:format".
_JSON_TO_DBT: dict[str, str] = {
    "string": "string",
    "string:date-time": "timestamp(3)",
    "string:date": "date",
    "string:time": "string",
    "integer": "int",
    "number": "double",
    "boolean": "boolean",
    "array": "array<string>",
    "object": "row<string>",
    "null": "string",
}

# Avro primitive / complex type → Flink / dbt type.
_AVRO_TO_DBT: dict[str, str] = {
    "string": "string",
    "int": "int",
    "long": "bigint",
    "float": "float",
    "double": "double",
    "boolean": "boolean",
    "bytes": "bytes",
    "fixed": "bytes",
    "null": "string",
}

# Avro logical type overrides.
_AVRO_LOGICAL_TO_DBT: dict[str, str] = {
    "timestamp-millis": "timestamp(3)",
    "timestamp-micros": "timestamp(3)",
    "local-timestamp-millis": "timestamp(3)",
    "local-timestamp-micros": "timestamp(3)",
    "date": "date",
    "time-millis": "string",
    "time-micros": "string",
    "decimal": "double",
    "uuid": "string",
}


# ── Schema → ColumnSpec ───────────────────────────────────────────────────────

@dataclass
class ColumnSpec:
    """One column entry in a dbt YAML file."""
    name: str
    data_type: str


def schema_to_columns(schema: dict[str, Any], schema_type: str) -> list[ColumnSpec]:
    """Convert a parsed schema dict to a list of :class:`ColumnSpec`.

    Args:
        schema:      Parsed schema dict as returned by :meth:`SchemaFetcher.fetch`.
        schema_type: ``"JSON"``, ``"AVRO"``, or ``"PROTOBUF"``.

    Returns:
        Ordered list of :class:`ColumnSpec` matching the schema fields.

    Raises:
        NotImplementedError: for Protobuf schemas (not yet supported).
        ValueError:           for unrecognised schema_type values.
    """
    if schema_type == "PROTOBUF":
        raise NotImplementedError(
            "Protobuf schema conversion is not yet supported. "
            "Register the schema as JSON or Avro to use this tool."
        )
    if schema_type == "AVRO":
        return _avro_to_columns(schema)
    if schema_type == "JSON":
        return _json_to_columns(schema)
    raise ValueError(f"Unknown schema_type '{schema_type}'. Expected JSON or AVRO.")


def _json_type(prop: dict[str, Any]) -> str:
    """Map a single JSON Schema property definition to a dbt type string."""
    # Unwrap Pydantic-style Optional: anyOf/oneOf containing a null branch.
    for key in ("anyOf", "oneOf"):
        if key in prop:
            non_null = [b for b in prop[key] if b.get("type") != "null" and b != {"type": "null"}]
            if non_null:
                return _json_type(non_null[0])

    raw_type: str = prop.get("type", "string")
    if isinstance(raw_type, list):
        # e.g. ["null", "string"] — take the first non-null
        non_null = [t for t in raw_type if t != "null"]
        raw_type = non_null[0] if non_null else "null"

    fmt: str | None = prop.get("format")
    lookup = f"{raw_type}:{fmt}" if fmt else raw_type
    return _JSON_TO_DBT.get(lookup) or _JSON_TO_DBT.get(raw_type, "string")


def _json_to_columns(schema: dict[str, Any]) -> list[ColumnSpec]:
    props: dict[str, Any] = schema.get("properties", {})
    return [ColumnSpec(name=name, data_type=_json_type(prop)) for name, prop in props.items()]


def _avro_type(field: dict[str, Any]) -> str:
    """Map a single Avro field definition to a dbt type string."""
    field_type = field.get("type")

    # Unwrap nullable union: ["null", "string"] or ["null", {...}]
    if isinstance(field_type, list):
        non_null = [t for t in field_type if t != "null"]
        field_type = non_null[0] if non_null else "null"

    # Named record / complex type given as a dict
    if isinstance(field_type, dict):
        logical = field_type.get("logicalType")
        if logical and logical in _AVRO_LOGICAL_TO_DBT:
            return _AVRO_LOGICAL_TO_DBT[logical]
        avro_base = field_type.get("type", "string")
        return _AVRO_TO_DBT.get(avro_base, "string")

    # Primitive string type name
    if isinstance(field_type, str):
        logical = field.get("logicalType")
        if logical and logical in _AVRO_LOGICAL_TO_DBT:
            return _AVRO_LOGICAL_TO_DBT[logical]
        return _AVRO_TO_DBT.get(field_type, "string")

    return "string"


def _avro_to_columns(schema: dict[str, Any]) -> list[ColumnSpec]:
    fields: list[dict[str, Any]] = schema.get("fields", [])
    return [ColumnSpec(name=f["name"], data_type=_avro_type(f)) for f in fields]


# ── YAML renderers ────────────────────────────────────────────────────────────

def render_sources_yaml(topic: str, schema_name: str, columns: list[ColumnSpec]) -> str:
    """Render a dbt ``sources:`` YAML block for a Kafka topic.

    The output matches the shape of ``models/sources.yaml`` in the
    airbnb_streaming dbt project (``contract.enforced: true``).

    Args:
        topic:       Kafka topic name — used for both the source ``name`` and
                     the ``tables[].name``.
        schema_name: Value placed in ``schema:`` (typically the Kafka cluster /
                     environment identifier, e.g. ``j9r-kafka``).
        columns:     Column definitions as returned by :func:`schema_to_columns`.

    Returns:
        YAML string ready to paste into ``models/sources.yaml``.
    """
    data = {
        "sources": [
            {
                "name": topic,
                "schema": schema_name,
                "tables": [
                    {
                        "name": topic,
                        "columns": [
                            {"name": col.name, "data_type": col.data_type}
                            for col in columns
                        ],
                    }
                ],
                "config": {"contract": {"enforced": True}},
            }
        ]
    }
    return yaml.safe_dump(data, sort_keys=False, default_flow_style=False, allow_unicode=True)


def render_model_yaml(model_name: str, columns: list[ColumnSpec]) -> str:
    """Render a dbt ``models:`` YAML block for a staging / source model.

    The output matches the shape of ``src_hosts_models.yml`` in the
    airbnb_streaming dbt project (``contract.enforced: false``).

    Args:
        model_name: dbt model name (e.g. ``src_hosts``).
        columns:    Column definitions as returned by :func:`schema_to_columns`.

    Returns:
        YAML string ready to paste into a model YAML file.
    """
    data = {
        "models": [
            {
                "name": model_name,
                "config": {"contract": {"enforced": False}},
                "columns": [
                    {"name": col.name, "data_type": col.data_type}
                    for col in columns
                ],
            }
        ]
    }
    return yaml.safe_dump(data, sort_keys=False, default_flow_style=False, allow_unicode=True)
