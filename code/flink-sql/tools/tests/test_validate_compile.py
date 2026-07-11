"""Tests for dbt compile validation helpers."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from flink_dbt_migrate.validate_compile import (
    DbtCompileError,
    compiled_model_path,
    find_dbt_project,
    read_compiled_sql,
    relative_model_path,
    resolve_ref_aliases,
    run_dbt_compile,
    validate_compiled_migration,
)

CC_FLINK = (
    Path(__file__).resolve().parents[2]
    / "10-windowing/tumble_then_hop_rolling/cc-flink"
)


def test_find_dbt_project_from_nested_model_path() -> None:
    model_dir = CC_FLINK / "models/sources"
    assert find_dbt_project(model_dir) == CC_FLINK.resolve()


def test_find_dbt_project_missing_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="dbt_project.yml"):
        find_dbt_project(tmp_path)


def test_relative_and_compiled_model_paths() -> None:
    model_path = CC_FLINK / "models/sources/raw_tx_events.sql"
    rel = relative_model_path(CC_FLINK, model_path)
    assert rel == Path("sources/raw_tx_events.sql")
    compiled = compiled_model_path(CC_FLINK, rel)
    assert compiled == CC_FLINK / "target/compiled/tumble_hop_wdw/sources/raw_tx_events.sql"


def test_read_compiled_sql_from_fixture(tmp_path: Path) -> None:
    compiled = tmp_path / "model.sql"
    compiled.write_text("SELECT 1", encoding="utf-8")
    assert read_compiled_sql(compiled) == "SELECT 1"


def test_resolve_ref_aliases_from_manifest(tmp_path: Path) -> None:
    manifest = {
        "nodes": {
            "model.demo.rolling_features": {
                "name": "rolling_features",
                "resource_type": "model",
                "depends_on": {"nodes": ["model.demo.events"]},
            },
            "model.demo.events": {
                "name": "events",
                "resource_type": "model",
                "relation_name": "`env`.`kafka`.`events`",
            },
        }
    }
    (tmp_path / "target").mkdir(parents=True)
    (tmp_path / "target" / "manifest.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )

    aliases = resolve_ref_aliases(tmp_path, "rolling_features", {"events": "src_events"})
    assert aliases["src_events"] == "events"
    assert aliases["env.kafka.events"] == "events"
    assert aliases["events"] == "events"


def test_run_dbt_compile_invokes_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    def fake_run(command, **kwargs):
        captured["command"] = command
        captured["kwargs"] = kwargs

        class Result:
            returncode = 0
            stdout = "compiled ok"
            stderr = ""

        return Result()

    monkeypatch.setattr(
        "flink_dbt_migrate.validate_compile.subprocess.run",
        fake_run,
    )

    completed = run_dbt_compile(
        CC_FLINK,
        "raw_tx_events",
        profiles_dir=Path("/tmp/profiles"),
        target="dev",
    )
    assert completed.returncode == 0
    assert captured["command"] == [
        "dbt",
        "compile",
        "--select",
        "raw_tx_events",
        "--project-dir",
        str(CC_FLINK),
        "--target",
        "dev",
        "--profiles-dir",
        "/tmp/profiles",
    ]


def test_validate_compiled_migration_reads_output(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    project_dir = tmp_path / "project"
    models_dir = project_dir / "models" / "marts"
    models_dir.mkdir(parents=True)
    (project_dir / "dbt_project.yml").write_text("name: demo\n", encoding="utf-8")

    model_path = models_dir / "rolling_features.sql"
    model_path.write_text("SELECT 1", encoding="utf-8")

    compiled_dir = project_dir / "target" / "compiled" / "demo" / "marts"
    compiled_dir.mkdir(parents=True)
    (compiled_dir / "rolling_features.sql").write_text(
        "SELECT user_id FROM events",
        encoding="utf-8",
    )

    def fake_run(command, **kwargs):
        class Result:
            returncode = 0
            stdout = ""
            stderr = ""

        return Result()

    monkeypatch.setattr(
        "flink_dbt_migrate.validate_compile.subprocess.run",
        fake_run,
    )

    result = validate_compiled_migration(
        project_dir,
        model_path,
        "rolling_features",
    )
    assert result.compiled_sql == "SELECT user_id FROM events"
    assert result.compiled_path.name == "rolling_features.sql"


def test_validate_compiled_migration_raises_on_dbt_failure(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    project_dir = tmp_path / "project"
    project_dir.mkdir()
    (project_dir / "dbt_project.yml").write_text("name: demo\n", encoding="utf-8")

    def fake_run(command, **kwargs):
        class Result:
            returncode = 1
            stdout = ""
            stderr = "Compilation Error: missing ref"

        return Result()

    monkeypatch.setattr(
        "flink_dbt_migrate.validate_compile.subprocess.run",
        fake_run,
    )

    with pytest.raises(DbtCompileError, match="missing ref"):
        validate_compiled_migration(
            project_dir,
            project_dir / "models/x.sql",
            "x",
        )
