#!/usr/bin/env python3
"""
Register, list, and delete Avro/JSON schemas in Schema Registry.

Register (RecordNameStrategy subject defaults):
  AVRO  — ``namespace.name`` from the ``.avsc``
  JSON  — ``title`` from the JSON Schema
Override with ``--subject``. Schema type is inferred from the extension
(``.avsc`` → AVRO, ``.json`` → JSON) or set with ``--type``.

Usage:
  uv run python -m cc_deploy.register_schema \\
    ../07-1-multiple-event-types/python/schemas/DeviceCloseDetail.avsc

  uv run python -m cc_deploy.register_schema register path/to/schema.json
  uv run python -m cc_deploy.register_schema list --output schema-manifest.json
  uv run python -m cc_deploy.register_schema delete --manifest schema-manifest.json
  uv run python -m cc_deploy.register_schema delete --manifest schema-manifest.json --permanent

Environment (``~/.confluent/.env`` by default; override with ``CONFLUENT_ENV_FILE``):
  SCHEMA_REGISTRY_ENDPOINT
  SCHEMA_REGISTRY_API_KEY / SCHEMA_REGISTRY_API_SECRET
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError

from cc_deploy.flink_deploy import load_dotenv_file

SchemaType = Literal["AVRO", "JSON"]

DEFAULT_MANIFEST_NAME = "schema-manifest.json"

_EXT_TO_TYPE: dict[str, SchemaType] = {
    ".avsc": "AVRO",
    ".json": "JSON",
}

_ACTIONS = frozenset({"list", "delete", "register"})


@dataclass(frozen=True)
class SchemaEntry:
    subject: str
    delete: bool


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


def list_subjects(
    client: SchemaRegistryClient | None = None,
) -> list[str]:
    """Return all subject names registered in Schema Registry."""
    sr = client or schema_registry_client()
    try:
        return list(sr.get_subjects())
    except SchemaRegistryError as exc:
        raise RuntimeError(f"Failed to list Schema Registry subjects: {exc}") from exc


def build_schema_manifest(
    subjects: list[str],
    *,
    endpoint: str,
) -> dict[str, Any]:
    """Build a schema-manifest dict from subject names."""
    return {
        "source": "schema_registry",
        "schema_registry_endpoint": endpoint,
        "generated_at": datetime.now(UTC).isoformat(),
        "schemas": [
            {"subject": subject, "delete": True}
            for subject in subjects
        ],
    }


def manifest_to_json(manifest: dict[str, Any]) -> str:
    return json.dumps(manifest, indent=2) + "\n"


def write_schema_manifest(manifest: dict[str, Any], path: Path) -> Path:
    path.write_text(manifest_to_json(manifest), encoding="utf-8")
    return path


def _entries_from_schemas_list(schemas: list[Any]) -> list[SchemaEntry]:
    entries: list[SchemaEntry] = []
    for item in schemas:
        if isinstance(item, str):
            entries.append(SchemaEntry(subject=item, delete=True))
        elif isinstance(item, dict):
            subject = item.get("subject")
            if not subject or not isinstance(subject, str):
                raise ValueError(f"Invalid schema entry (missing subject): {item!r}")
            delete = bool(item.get("delete", True))
            entries.append(SchemaEntry(subject=subject, delete=delete))
        else:
            raise ValueError(f"Invalid schema entry type: {item!r}")
    return entries


def load_schema_manifest(path: Path) -> tuple[list[SchemaEntry], dict[str, Any]]:
    """
    Load schema-manifest.json.

    Returns (entries, raw manifest dict).
    """
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    if "schemas" not in data:
        raise ValueError(f"Manifest {path} must contain 'schemas'")
    entries = _entries_from_schemas_list(data["schemas"])
    return entries, data


def subjects_to_delete(entries: list[SchemaEntry]) -> list[str]:
    """Return subject names marked for delete, preserving manifest order."""
    return [entry.subject for entry in entries if entry.delete]


def delete_subjects(
    subjects: list[str],
    *,
    permanent: bool = False,
    client: SchemaRegistryClient | None = None,
) -> list[tuple[str, list[int]]]:
    """
    Soft- or permanently-delete each subject.

    Returns list of ``(subject, deleted_versions)``.
    Raises on the first Schema Registry failure.
    """
    sr = client or schema_registry_client()
    results: list[tuple[str, list[int]]] = []
    for subject in subjects:
        try:
            versions = sr.delete_subject(subject, permanent=permanent)
        except SchemaRegistryError as exc:
            raise RuntimeError(
                f"Failed to delete subject '{subject}' "
                f"(permanent={permanent}): {exc}"
            ) from exc
        results.append((subject, list(versions)))
    return results


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


def _add_register_args(parser: argparse.ArgumentParser) -> None:
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


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    raw = list(sys.argv[1:] if argv is None else argv)

    # Backward compat: bare path (no list/delete/register) → register
    if raw and raw[0] not in _ACTIONS and not raw[0].startswith("-"):
        raw = ["register", *raw]

    parser = argparse.ArgumentParser(
        description=(
            "Register, list, or delete Avro/JSON schemas in Schema Registry. "
            "Register subject defaults to namespace.name (AVRO) or title (JSON)."
        )
    )
    sub = parser.add_subparsers(dest="action", required=True)

    register_p = sub.add_parser("register", help="Register a schema file")
    _add_register_args(register_p)

    list_p = sub.add_parser("list", help="List subjects and write schema-manifest.json")
    list_p.add_argument(
        "--output",
        type=Path,
        default=Path(DEFAULT_MANIFEST_NAME),
        help=f"Output manifest path (default: {DEFAULT_MANIFEST_NAME})",
    )
    list_p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print manifest JSON without writing a file",
    )

    delete_p = sub.add_parser("delete", help="Delete subjects marked in the manifest")
    delete_p.add_argument(
        "--manifest",
        type=Path,
        default=Path(DEFAULT_MANIFEST_NAME),
        help=f"Schema manifest path (default: {DEFAULT_MANIFEST_NAME})",
    )
    delete_p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print subjects that would be deleted without calling Schema Registry",
    )
    delete_p.add_argument(
        "--permanent",
        action="store_true",
        help="Permanently delete subjects (default: soft delete)",
    )

    return parser.parse_args(raw)


def cmd_register(args: argparse.Namespace) -> None:
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


def cmd_list(args: argparse.Namespace) -> None:
    try:
        subjects = list_subjects()
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    endpoint = os.environ.get("SCHEMA_REGISTRY_ENDPOINT", "http://localhost:8081")
    manifest = build_schema_manifest(subjects, endpoint=endpoint)
    payload = json.dumps(manifest, indent=2)

    if args.dry_run:
        print(payload)
        print(f"\n(dry-run: not written to {args.output})", file=sys.stderr)
        return

    write_schema_manifest(manifest, args.output.resolve())
    print(payload)
    print(f"\nWrote {args.output.resolve()}", file=sys.stderr)
    print(
        "Edit the manifest (set delete: false or remove rows) before running delete.",
        file=sys.stderr,
    )


def cmd_delete(args: argparse.Namespace) -> None:
    manifest_path = args.manifest.resolve()
    if not manifest_path.is_file():
        print(f"Manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    try:
        entries, _raw = load_schema_manifest(manifest_path)
    except (ValueError, json.JSONDecodeError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    subjects = subjects_to_delete(entries)
    if not subjects:
        print("No subjects marked for delete in manifest.", file=sys.stderr)
        sys.exit(1)

    mode = "permanent" if args.permanent else "soft"
    if args.dry_run:
        for subject in subjects:
            print(f"DELETE SUBJECT {subject} ({mode})")
        print(
            f"\n(dry-run: {len(subjects)} subject(s), no API calls)",
            file=sys.stderr,
        )
        return

    try:
        results = delete_subjects(subjects, permanent=args.permanent)
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    for subject, versions in results:
        print(f"Deleted {subject} versions={versions} ({mode})")
    print(f"delete complete ({len(results)} subject(s), {mode}).")


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    load_dotenv_file()

    if args.action == "register":
        cmd_register(args)
    elif args.action == "list":
        cmd_list(args)
    elif args.action == "delete":
        cmd_delete(args)


if __name__ == "__main__":
    main()
