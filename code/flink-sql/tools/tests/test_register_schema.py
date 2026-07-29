"""Unit tests for subject derivation, type inference, and schema manifest helpers."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cc_deploy.register_schema import (
    SchemaEntry,
    avro_fqn_from_file,
    avro_fqn_from_payload,
    build_schema_manifest,
    infer_schema_type,
    json_subject_from_payload,
    load_schema_manifest,
    parse_args,
    subject_from_payload,
    subjects_to_delete,
    write_schema_manifest,
)


def test_avro_fqn_with_namespace() -> None:
    assert (
        avro_fqn_from_payload(
            {
                "type": "record",
                "name": "DeviceCloseDetail",
                "namespace": "io.confluent.flink.multievent",
                "fields": [],
            }
        )
        == "io.confluent.flink.multievent.DeviceCloseDetail"
    )


def test_avro_fqn_without_namespace() -> None:
    assert avro_fqn_from_payload({"type": "record", "name": "Plain"}) == "Plain"


def test_avro_fqn_requires_name() -> None:
    with pytest.raises(ValueError, match="name"):
        avro_fqn_from_payload({"type": "record"})


def test_avro_fqn_from_device_close_detail() -> None:
    src = (
        Path(__file__).resolve().parents[2]
        / "07-1-multiple-event-types"
        / "python"
        / "schemas"
        / "DeviceCloseDetail.avsc"
    )
    if not src.is_file():
        pytest.skip("DeviceCloseDetail.avsc not found relative to tools/")
    assert (
        avro_fqn_from_file(src)
        == "io.confluent.flink.multievent.DeviceCloseDetail"
    )


def test_avro_fqn_from_written_file(tmp_path: Path) -> None:
    path = tmp_path / "Sample.avsc"
    path.write_text(
        json.dumps(
            {
                "type": "record",
                "name": "Sample",
                "namespace": "example",
                "fields": [{"name": "id", "type": "string"}],
            }
        ),
        encoding="utf-8",
    )
    assert avro_fqn_from_file(path) == "example.Sample"


def test_json_subject_from_title() -> None:
    assert (
        json_subject_from_payload(
            {
                "$schema": "http://json-schema.org/draft-07/schema#",
                "title": "DeviceCloseDetail",
                "type": "object",
                "properties": {"accountId": {"type": "string"}},
            }
        )
        == "DeviceCloseDetail"
    )


def test_json_subject_requires_title() -> None:
    with pytest.raises(ValueError, match="title"):
        json_subject_from_payload({"type": "object"})


def test_subject_from_payload_dispatches() -> None:
    assert (
        subject_from_payload({"name": "A", "namespace": "ns"}, "AVRO") == "ns.A"
    )
    assert subject_from_payload({"title": "B"}, "JSON") == "B"


def test_infer_schema_type_from_extension() -> None:
    assert infer_schema_type(Path("x.avsc")) == "AVRO"
    assert infer_schema_type(Path("x.json")) == "JSON"
    assert infer_schema_type(Path("x.json"), explicit="AVRO") == "AVRO"
    with pytest.raises(ValueError, match="infer"):
        infer_schema_type(Path("x.yaml"))


def test_build_schema_manifest() -> None:
    manifest = build_schema_manifest(
        ["ns.A", "ns.B"],
        endpoint="https://sr.example",
    )
    assert manifest["source"] == "schema_registry"
    assert manifest["schema_registry_endpoint"] == "https://sr.example"
    assert "generated_at" in manifest
    assert manifest["schemas"] == [
        {"subject": "ns.A", "delete": True},
        {"subject": "ns.B", "delete": True},
    ]


def test_write_and_load_schema_manifest(tmp_path: Path) -> None:
    path = tmp_path / "schema-manifest.json"
    manifest = build_schema_manifest(["foo.Bar"], endpoint="http://localhost:8081")
    write_schema_manifest(manifest, path)

    entries, raw = load_schema_manifest(path)
    assert raw["schemas"][0]["subject"] == "foo.Bar"
    assert entries == [SchemaEntry(subject="foo.Bar", delete=True)]


def test_load_schema_manifest_shorthand_strings(tmp_path: Path) -> None:
    path = tmp_path / "schema-manifest.json"
    path.write_text(
        json.dumps({"schemas": ["a.A", {"subject": "b.B", "delete": False}]}),
        encoding="utf-8",
    )
    entries, _ = load_schema_manifest(path)
    assert entries == [
        SchemaEntry(subject="a.A", delete=True),
        SchemaEntry(subject="b.B", delete=False),
    ]


def test_load_schema_manifest_requires_schemas(tmp_path: Path) -> None:
    path = tmp_path / "bad.json"
    path.write_text("{}", encoding="utf-8")
    with pytest.raises(ValueError, match="schemas"):
        load_schema_manifest(path)


def test_subjects_to_delete() -> None:
    entries = [
        SchemaEntry(subject="keep", delete=False),
        SchemaEntry(subject="drop", delete=True),
        SchemaEntry(subject="also", delete=True),
    ]
    assert subjects_to_delete(entries) == ["drop", "also"]


def test_parse_args_bare_path_is_register() -> None:
    args = parse_args(["path/to/schema.avsc", "--subject", "X"])
    assert args.action == "register"
    assert args.schema == Path("path/to/schema.avsc")
    assert args.subject == "X"


def test_parse_args_list_and_delete() -> None:
    list_args = parse_args(["list", "--dry-run"])
    assert list_args.action == "list"
    assert list_args.dry_run is True

    delete_args = parse_args(["delete", "--permanent", "--manifest", "m.json"])
    assert delete_args.action == "delete"
    assert delete_args.permanent is True
    assert delete_args.manifest == Path("m.json")
