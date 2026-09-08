#!/usr/bin/env python3
"""
Register, list, and delete Avro/JSON schemas in Schema Registry.

Register (RecordNameStrategy subject defaults):
  AVRO  — ``namespace.name`` from the ``.avsc``
  JSON  — ``title`` from the JSON Schema
Override with ``--subject``. Schema type is inferred from the extension
(``.avsc`` → AVRO, ``.json`` → JSON) or set with ``--type``.

Usage:
  uv run python -m kafka.register_schema \\
    ../07-1-multiple-event-types/python/schemas/DeviceCloseDetail.avsc

  uv run python -m kafka.register_schema register path/to/schema.json
  uv run python -m kafka.register_schema list --output schema-manifest.json
  uv run python -m kafka.register_schema delete --manifest schema-manifest.json
  uv run python -m kafka.register_schema delete --manifest schema-manifest.json --permanent

  # When a schema is referenced by another schema (SR error 42206), resolve
  # and delete the referencing schemas first:
  uv run python -m kafka.register_schema delete --manifest schema-manifest.json --permanent --resolve-references

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

import urllib.parse

import requests

from confluent_kafka.schema_registry import Schema, SchemaRegistryClient
from confluent_kafka.schema_registry.error import SchemaRegistryError

from cc_deploy.deploy_flink_statements import load_dotenv_file

SchemaType = Literal["AVRO", "JSON"]

DEFAULT_MANIFEST_NAME = "schema-manifest.json"

_EXT_TO_TYPE: dict[str, SchemaType] = {
    ".avsc": "AVRO",
    ".json": "JSON",
}

_ACTIONS = frozenset({"list", "delete", "register", "debug-refs"})


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


# ---------------------------------------------------------------------------
# Reference resolution helpers
# ---------------------------------------------------------------------------

def _sr_http_session() -> tuple[str, requests.Session]:
    """Return (base_url, authenticated requests.Session) from env."""
    url = os.environ.get("SCHEMA_REGISTRY_ENDPOINT", "http://localhost:8081").rstrip("/")
    session = requests.Session()
    user = os.environ.get("SCHEMA_REGISTRY_API_KEY", "")
    password = os.environ.get("SCHEMA_REGISTRY_API_SECRET", "")
    if user:
        session.auth = (user, password)
    return url, session


def get_subject_versions(subject: str, *, include_deleted: bool = False) -> list[int]:
    """Return all version numbers registered under *subject*."""
    base, session = _sr_http_session()
    params = {"deleted": "true"} if include_deleted else {}
    encoded = urllib.parse.quote(subject, safe="")
    resp = session.get(f"{base}/subjects/{encoded}/versions", params=params, timeout=10)
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    return resp.json()


def get_referencedby(subject: str, version: int | str = "latest") -> list[int]:
    """
    Return the list of global schema IDs that reference ``subject`` at ``version``.

    Queries both the active and deleted registrations so that soft-deleted
    referencing schemas are included in the result.

    Uses the Schema Registry REST API endpoint:
      GET /subjects/{subject}/versions/{version}/referencedby
    """
    base, session = _sr_http_session()
    encoded = urllib.parse.quote(subject, safe="")
    url = f"{base}/subjects/{encoded}/versions/{version}/referencedby"
    # ?deleted=true surfaces IDs whose referencing subject was already soft-deleted
    all_ids: set[int] = set()
    for params in ({}, {"deleted": "true"}):
        resp = session.get(url, params=params, timeout=10)
        if resp.status_code == 404:
            continue
        resp.raise_for_status()
        result = resp.json()
        if isinstance(result, list):
            all_ids.update(result)
    return list(all_ids)


def get_subject_for_schema_id(schema_id: int) -> list[str]:
    """
    Return subjects that own the given global schema ID.

    Uses: GET /schemas/ids/{id}/versions
    Returns a list of {"subject": ..., "version": ...} objects.
    """
    base, session = _sr_http_session()
    # /schemas/ids/{id}/versions returns [{"subject":..,"version":..}, ...]
    for params in ({}, {"deleted": "true"}):
        resp = session.get(
            f"{base}/schemas/ids/{schema_id}/versions",
            params=params,
            timeout=10,
        )
        if resp.status_code == 404:
            continue
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list) and data:
            return [
                item["subject"]
                for item in data
                if isinstance(item, dict) and "subject" in item
            ]
    return []


def resolve_delete_order(subjects: list[str]) -> list[str]:
    """
    Expand *subjects* with any schemas that reference them, ordered so that
    referencing schemas come before the schemas they reference.

    Algorithm: BFS from each requested subject through ``referencedby``,
    then return a topologically sorted list (referencing first, referenced last).
    """
    # BFS: discover all referencing schema IDs and map them back to subjects
    all_subjects: list[str] = list(subjects)
    visited_ids: set[int] = set()
    queue: list[str] = list(subjects)

    while queue:
        subject = queue.pop(0)
        versions = get_subject_versions(subject)
        for version in versions:
            ref_ids = get_referencedby(subject, version)
            for schema_id in ref_ids:
                if schema_id in visited_ids:
                    continue
                visited_ids.add(schema_id)
                ref_subjects = get_subject_for_schema_id(schema_id)
                for ref_subj in ref_subjects:
                    if ref_subj not in all_subjects:
                        print(
                            f"  [resolve] '{ref_subj}' references '{subject}' "
                            f"(schema_id={schema_id}) — will delete first",
                            file=sys.stderr,
                        )
                        all_subjects.insert(0, ref_subj)
                        queue.append(ref_subj)

    # Referencing subjects were prepended; the original subjects land at the end.
    # Deduplicate while preserving order (first occurrence wins = referencing first).
    seen: set[str] = set()
    ordered: list[str] = []
    for s in all_subjects:
        if s not in seen:
            seen.add(s)
            ordered.append(s)
    return ordered


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

# SR 404-family error codes that mean "already gone / already soft-deleted"
_SR_404_CODES = frozenset({
    40401,  # Subject not found
    40402,  # Version not found (Confluent Cloud: "was soft deleted")
    40403,  # Schema not found
    40404,  # Subject version soft-deleted
})


def _delete_subject_permanent(subject: str, sr: SchemaRegistryClient) -> list[int]:
    """
    Permanently delete *subject* using the required two-step sequence:
      1. Soft-delete  (marks versions as deleted)
      2. Hard-delete  (permanent=True removes them from storage)

    Step 1 is skipped gracefully if the subject is already soft-deleted
    (Confluent Cloud returns SR codes 40401/40402/40403 in that case).
    """
    try:
        sr.delete_subject(subject, permanent=False)
    except SchemaRegistryError as exc:
        # Any 404-family code means "already soft-deleted" — safe to continue
        if exc.error_code not in _SR_404_CODES:
            raise RuntimeError(
                f"Failed to soft-delete subject '{subject}': {exc}"
            ) from exc
        print(
            f"  [info] '{subject}' already soft-deleted, proceeding to permanent delete",
            file=sys.stderr,
        )

    try:
        versions = sr.delete_subject(subject, permanent=True)
    except SchemaRegistryError as exc:
        raise RuntimeError(
            f"Failed to permanently delete subject '{subject}': {exc}"
        ) from exc
    return list(versions)


def delete_subjects(
    subjects: list[str],
    *,
    permanent: bool = False,
    resolve_references: bool = False,
    client: SchemaRegistryClient | None = None,
) -> list[tuple[str, list[int]]]:
    """
    Soft- or permanently-delete each subject.

    When *resolve_references* is True (recommended with *permanent=True*),
    any schemas that reference the requested subjects are discovered via the
    ``/referencedby`` API and deleted first so that Schema Registry error
    42206 is avoided.

    Permanent deletion uses the required two-step sequence (soft then hard)
    so that Confluent Cloud SR does not return 42206 on already-active schemas.

    Returns list of ``(subject, deleted_versions)``.
    Raises on the first Schema Registry failure.
    """
    if resolve_references:
        print("Resolving schema references …", file=sys.stderr)
        subjects = resolve_delete_order(subjects)

    sr = client or schema_registry_client()
    results: list[tuple[str, list[int]]] = []
    for subject in subjects:
        try:
            if permanent:
                versions = _delete_subject_permanent(subject, sr)
            else:
                versions = list(sr.delete_subject(subject, permanent=False))
        except RuntimeError:
            raise
        except SchemaRegistryError as exc:
            raise RuntimeError(
                f"Failed to delete subject '{subject}' "
                f"(permanent={permanent}): {exc}"
            ) from exc
        results.append((subject, versions))
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


def cmd_debug_refs(args: argparse.Namespace) -> None:
    """Print every version of a subject and the schema IDs that reference it."""
    subject = args.subject
    print(f"\nSubject: {subject}")

    versions = get_subject_versions(subject, include_deleted=True)
    if not versions:
        print("  No versions found (subject may not exist).")
        return

    print(f"  Versions: {versions}")
    for version in versions:
        ref_ids = get_referencedby(subject, version)
        print(f"  Version {version} — referencedby IDs: {ref_ids or '(none)'}")
        for schema_id in ref_ids:
            ref_subjects = get_subject_for_schema_id(schema_id)
            print(f"    schema_id={schema_id} → subjects: {ref_subjects}")


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

    debug_p = sub.add_parser(
        "debug-refs",
        help="Show which schema IDs reference a given subject (for diagnosing error 42206)",
    )
    debug_p.add_argument("subject", help="Subject name to inspect")

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
    delete_p.add_argument(
        "--resolve-references",
        action="store_true",
        dest="resolve_references",
        help=(
            "Before deleting, discover schemas that reference the target subjects "
            "and delete them first (avoids SR error 42206). "
            "Implied automatically when --permanent is used."
        ),
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

    # --resolve-references is implied when --permanent is used
    resolve = args.resolve_references or args.permanent

    mode = "permanent" if args.permanent else "soft"
    if args.dry_run:
        if resolve:
            print("Resolving schema references (dry-run) …", file=sys.stderr)
            subjects = resolve_delete_order(subjects)
        for subject in subjects:
            print(f"DELETE SUBJECT {subject} ({mode})")
        print(
            f"\n(dry-run: {len(subjects)} subject(s), no API calls)",
            file=sys.stderr,
        )
        return

    try:
        results = delete_subjects(
            subjects,
            permanent=args.permanent,
            resolve_references=resolve,
        )
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
    elif args.action == "debug-refs":
        cmd_debug_refs(args)


if __name__ == "__main__":
    main()
