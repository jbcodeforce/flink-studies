#!/usr/bin/env python3
"""
Register an Avro or JSON Schema file in Schema Registry (RecordNameStrategy).

Subject defaults:
  AVRO  — ``namespace.name`` from the ``.avsc``
  JSON  — ``title`` from the JSON Schema
Override with ``--subject``. Schema type is inferred from the extension
(``.avsc`` → AVRO, ``.json`` → JSON) or set with ``--type``.

Usage:
  uv run python -m cc_deploy.register_schema \\
    ../07-1-multiple-event-types/python/schemas/DeviceCloseDetail.avsc

  uv run python -m cc_deploy.register_schema path/to/schema.json
  uv run python -m cc_deploy.register_schema path/to/schema.json --subject my.Subject

Environment (``~/.confluent/.env`` by default; override with ``CONFLUENT_ENV_FILE``):
  SCHEMA_REGISTRY_ENDPOINT
  SCHEMA_REGISTRY_API_KEY / SCHEMA_REGISTRY_API_SECRET
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Literal

from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError

from cc_deploy.flink_deploy import load_dotenv_file

SchemaType = Literal["AVRO", "JSON"]

_EXT_TO_TYPE: dict[str, SchemaType] = {
    ".avsc": "AVRO",
    ".json": "JSON",
}


def avro_fqn_from_payload(payload: dict) -> str:
    """Return ``namespace.name`` (or ``name``) for a RecordNameStrategy subject."""
    name = payload.get("name")
    if not name or not isinstance(name, str):
        raise ValueError("Avro schema must include a string 'name' field")
    namespace = payload.get("namespace")
    if namespace:
        return f"{namespace}.{name}"
    return name


def json_subject_from_payload(payload: dict) -> str:
    """Return JSON Schema ``title`` for a RecordNameStrategy subject."""
    title = payload.get("title")
    if not title or not isinstance(title, str):
        raise ValueError(
            "JSON Schema must include a string 'title' field to derive the subject, "
            "or pass --subject"
        )
    return title


def subject_from_payload(payload: dict, schema_type: SchemaType) -> str:
    if schema_type == "AVRO":
        return avro_fqn_from_payload(payload)
    return json_subject_from_payload(payload)


def infer_schema_type(schema_path: Path, explicit: str | None = None) -> SchemaType:
    if explicit:
        value = explicit.upper()
        if value not in ("AVRO", "JSON"):
            raise ValueError(f"Unsupported schema type: {explicit!r} (use AVRO or JSON)")
        return value  # type: ignore[return-value]
    inferred = _EXT_TO_TYPE.get(schema_path.suffix.lower())
    if inferred is None:
        raise ValueError(
            f"Cannot infer schema type from extension {schema_path.suffix!r}; "
            "use --type AVRO|JSON"
        )
    return inferred


def schema_registry_client() -> SchemaRegistryClient:
    url = os.environ.get("SCHEMA_REGISTRY_ENDPOINT", "http://localhost:8081")
    user = os.environ.get("SCHEMA_REGISTRY_API_KEY", "")
    password = os.environ.get("SCHEMA_REGISTRY_API_SECRET", "")
    conf: dict[str, str] = {"url": url}
    if user:
        conf["basic.auth.user.info"] = f"{user}:{password}"
    print("=== Schema Registry Configuration ===")
    print(f"URL: {url}")
    print(f"Auth enabled: {bool(user)}")
    return SchemaRegistryClient(conf)


def register_schema(
    schema_path: Path,
    *,
    subject: str | None = None,
    schema_type: SchemaType | None = None,
) -> tuple[str, int, int | None, SchemaType]:
    """
    Register ``schema_path`` under ``subject`` (or derived RecordNameStrategy name).

    Returns ``(subject, schema_id, version, schema_type)``.
    """
    if not schema_path.is_file():
        raise FileNotFoundError(f"Schema file not found: {schema_path}")

    resolved_type = schema_type or infer_schema_type(schema_path)
    schema_str = schema_path.read_text(encoding="utf-8")
    payload = json.loads(schema_str)
    if not isinstance(payload, dict):
        raise ValueError(f"Schema root must be a JSON object: {schema_path}")

    resolved_subject = subject or subject_from_payload(payload, resolved_type)
    client = schema_registry_client()
    schema = Schema(schema_str, schema_type=resolved_type)

    try:
        registered = client.register_schema_full_response(resolved_subject, schema)
    except SchemaRegistryError as exc:
        raise RuntimeError(
            f"Failed to register {resolved_type} schema under subject "
            f"'{resolved_subject}': {exc}"
        ) from exc

    schema_id = registered.schema_id
    version = registered.version
    if version is None:
        try:
            version = client.get_latest_version(resolved_subject).version
        except SchemaRegistryError:
            version = None

    return resolved_subject, schema_id, version, resolved_type


# Back-compat alias used by early callers/tests
def register_avro_schema(
    schema_path: Path,
    *,
    subject: str | None = None,
) -> tuple[str, int, int | None]:
    subj, schema_id, version, _ = register_schema(
        schema_path, subject=subject, schema_type="AVRO"
    )
    return subj, schema_id, version


def avro_fqn_from_file(schema_path: Path) -> str:
    payload = json.loads(schema_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Avro schema root must be a JSON object: {schema_path}")
    return avro_fqn_from_payload(payload)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Register an Avro (.avsc) or JSON Schema (.json) in Schema Registry. "
            "Subject defaults to namespace.name (AVRO) or title (JSON)."
        )
    )
    parser.add_argument(
        "schema",
        type=Path,
        help="Path to .avsc or .json schema file",
    )
    parser.add_argument(
        "--subject",
        default=None,
        help="Schema Registry subject (default: derived from schema contents)",
    )
    parser.add_argument(
        "--type",
        dest="schema_type",
        choices=["AVRO", "JSON", "avro", "json"],
        default=None,
        help="Schema type (default: inferred from file extension)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    load_dotenv_file()

    explicit_type: SchemaType | None = None
    if args.schema_type:
        explicit_type = args.schema_type.upper()  # type: ignore[assignment]

    try:
        subject, schema_id, version, schema_type = register_schema(
            args.schema,
            subject=args.subject,
            schema_type=explicit_type,
        )
    except (FileNotFoundError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    print(f"Type: {schema_type}")
    print(f"Subject: {subject}")
    print(f"Schema id: {schema_id}")
    if version is not None:
        print(f"Version: {version}")


if __name__ == "__main__":
    main()
