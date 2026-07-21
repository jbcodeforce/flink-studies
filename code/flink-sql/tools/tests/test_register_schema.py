"""Unit tests for subject derivation and type inference (no Schema Registry network)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cc_deploy.register_schema import (
    avro_fqn_from_file,
    avro_fqn_from_payload,
    infer_schema_type,
    json_subject_from_payload,
    subject_from_payload,
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
