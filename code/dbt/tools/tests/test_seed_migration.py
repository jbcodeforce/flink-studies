"""Tests for INSERT INTO ... VALUES → dbt seed migration."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml
from typer.testing import CliRunner

from flink_dbt_migrate.emit_seed import (
    build_seed_schema_entry,
    emit_seed_csv,
    emit_seed_schema_yml,
    merge_seed_schema,
)
from flink_dbt_migrate.migrate import migrate_values_dml_to_seed
from flink_dbt_migrate.migrate_dml_to_dbt import app, crawl_pipeline_folder
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import is_values_insert, parse_values_dml

APP_USAGE_DDL = """\
create table app_usage_raw (
    usage_id STRING,
    customer_id STRING,
    session_date DATE,
    session_start TIMESTAMP(3),
    session_duration_minutes INTEGER,
    device_type STRING
) distributed by hash(usage_id) into 1 buckets with (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
)
"""

APP_USAGE_DML = """\
INSERT INTO app_usage_raw (
    usage_id,
    customer_id,
    session_date,
    session_start,
    session_duration_minutes,
    device_type
)
VALUES
    ('USG001', 'TEST001', DATE '2024-06-01', TIMESTAMP '2024-06-01 08:30:00', 25, 'ios'),
    ('USG002', 'TEST001', DATE '2024-06-02', TIMESTAMP '2024-06-02 19:15:00', 45, 'android');
"""

NO_COLUMN_LIST_DML = """\
INSERT INTO app_usage_raw VALUES
    ('USG001', 'TEST001', DATE '2024-06-01', TIMESTAMP '2024-06-01 08:30:00', 25, 'ios'),
    ('USG002', 'TEST001', DATE '2024-06-02', TIMESTAMP '2024-06-02 19:15:00', 45, 'android');
"""


@pytest.fixture
def cli_runner() -> CliRunner:
    return CliRunner()


def _write_seed_pair(tmp_path: Path, dml_text: str = APP_USAGE_DML) -> tuple[Path, Path]:
    ddl_path = tmp_path / "ddl.app_usage_raw.sql"
    dml_path = tmp_path / "dml.app_usage_raw.sql"
    ddl_path.write_text(APP_USAGE_DDL, encoding="utf-8")
    dml_path.write_text(dml_text, encoding="utf-8")
    return dml_path, ddl_path


# ---------------------------------------------------------------------------
# parse_dml: detection + VALUES parsing
# ---------------------------------------------------------------------------

def test_is_values_insert_detects_values_statement() -> None:
    assert is_values_insert(APP_USAGE_DML) is True


def test_is_values_insert_false_for_select_statement() -> None:
    assert is_values_insert("INSERT INTO t SELECT * FROM other") is False


def test_parse_values_dml_extracts_table_columns_rows() -> None:
    result = parse_values_dml(APP_USAGE_DML, source_file="dml.app_usage_raw.sql")

    assert result.target_table == "app_usage_raw"
    assert result.columns == [
        "usage_id",
        "customer_id",
        "session_date",
        "session_start",
        "session_duration_minutes",
        "device_type",
    ]
    assert len(result.rows) == 2
    assert result.rows[0] == [
        "USG001",
        "TEST001",
        "2024-06-01",
        "2024-06-01 08:30:00",
        "25",
        "ios",
    ]


def test_parse_values_dml_handles_null_and_escaped_quotes() -> None:
    sql = "INSERT INTO t (a, b, c) VALUES (1, NULL, 'it''s ok'), (2, 'x', NULL);"
    result = parse_values_dml(sql)

    assert result.rows[0] == ["1", None, "it's ok"]
    assert result.rows[1] == ["2", "x", None]


def test_parse_values_dml_handles_comma_inside_quoted_string() -> None:
    sql = "INSERT INTO t (a, b) VALUES (1, 'value, with comma');"
    result = parse_values_dml(sql)

    assert result.rows[0] == ["1", "value, with comma"]


def test_parse_values_dml_without_column_list_returns_empty_columns() -> None:
    result = parse_values_dml(NO_COLUMN_LIST_DML)

    assert result.target_table == "app_usage_raw"
    assert result.columns == []
    assert len(result.rows) == 2
    assert result.rows[0][0] == "USG001"


def test_parse_values_dml_rejects_mismatched_row_arity() -> None:
    sql = "INSERT INTO t (a, b) VALUES (1, 2), (3);"
    with pytest.raises(ValueError, match="values"):
        parse_values_dml(sql)


def test_parse_dml_still_rejects_values_statement() -> None:
    from flink_dbt_migrate.parse_dml import parse_dml

    with pytest.raises(ValueError, match="VALUES"):
        parse_dml(APP_USAGE_DML)


# ---------------------------------------------------------------------------
# emit_seed: CSV + schema.yml generation
# ---------------------------------------------------------------------------

def test_emit_seed_csv_quotes_commas() -> None:
    csv_text = emit_seed_csv(["a", "b"], [["1", "value, with comma"], ["2", None]])

    lines = csv_text.splitlines()
    assert lines[0] == "a,b"
    assert lines[1] == '1,"value, with comma"'
    assert lines[2] == "2,"


def test_build_seed_schema_entry_maps_types_and_with_options() -> None:
    ddl = parse_ddl(APP_USAGE_DDL)
    entry = build_seed_schema_entry("app_usage_raw", ddl, source_filename="dml.app_usage_raw.sql")

    assert entry["name"] == "app_usage_raw"
    assert entry["config"]["column_types"]["session_start"] == "TIMESTAMP(3)"
    assert entry["config"]["column_types"]["session_duration_minutes"] == "INT"
    assert entry["meta"]["flink_ddl_with_options"]["key.format"] == "avro-registry"


def test_emit_seed_schema_yml_writes_new_file(tmp_path: Path) -> None:
    ddl = parse_ddl(APP_USAGE_DDL)
    yml_text = emit_seed_schema_yml(tmp_path, "app_usage_raw", ddl, source_filename="dml.app_usage_raw.sql")

    data = yaml.safe_load(yml_text)
    assert data["version"] == 2
    assert data["seeds"][0]["name"] == "app_usage_raw"


def test_merge_seed_schema_preserves_existing_entry_without_force() -> None:
    data = {
        "version": 2,
        "seeds": [
            {
                "name": "app_usage_raw",
                "description": "hand-written",
                "config": {"column_types": {"usage_id": "string"}},
            }
        ],
    }
    ddl = parse_ddl(APP_USAGE_DDL)
    new_entry = build_seed_schema_entry("app_usage_raw", ddl)
    merge_seed_schema(data, new_entry, force=False)

    entry = data["seeds"][0]
    assert entry["description"] == "hand-written"
    assert entry["config"]["column_types"]["session_start"] == "TIMESTAMP(3)"


def test_merge_seed_schema_force_replaces_entry() -> None:
    data = {
        "version": 2,
        "seeds": [{"name": "app_usage_raw", "description": "stale", "config": {"column_types": {}}}],
    }
    ddl = parse_ddl(APP_USAGE_DDL)
    new_entry = build_seed_schema_entry("app_usage_raw", ddl, source_filename="dml.app_usage_raw.sql")
    merge_seed_schema(data, new_entry, force=True)

    assert data["seeds"][0]["description"] == "Migrated from dml.app_usage_raw.sql"


# ---------------------------------------------------------------------------
# migrate.migrate_values_dml_to_seed (orchestration)
# ---------------------------------------------------------------------------

def test_migrate_values_dml_to_seed(tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path)
    seeds_dir = tmp_path / "seeds"

    result = migrate_values_dml_to_seed(dml_path, seeds_dir)

    assert result.seed_name == "app_usage_raw"
    assert result.csv_path == seeds_dir / "app_usage_raw.csv"
    lines = result.csv_text.splitlines()
    assert lines[0] == "usage_id,customer_id,session_date,session_start,session_duration_minutes,device_type"
    assert "USG001" in lines[1]

    schema = yaml.safe_load(result.schema_yml)
    assert schema["seeds"][0]["config"]["column_types"]["session_date"] == "DATE"


def test_migrate_values_dml_to_seed_without_column_list_uses_ddl_order(tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path, dml_text=NO_COLUMN_LIST_DML)
    seeds_dir = tmp_path / "seeds"

    result = migrate_values_dml_to_seed(dml_path, seeds_dir)

    header = result.csv_text.splitlines()[0]
    assert header == "usage_id,customer_id,session_date,session_start,session_duration_minutes,device_type"


def test_migrate_values_dml_to_seed_arity_mismatch_without_columns(tmp_path: Path) -> None:
    bad_dml = "INSERT INTO app_usage_raw VALUES ('USG001', 'TEST001');"
    dml_path, _ = _write_seed_pair(tmp_path, dml_text=bad_dml)
    seeds_dir = tmp_path / "seeds"

    with pytest.raises(ValueError, match="columns"):
        migrate_values_dml_to_seed(dml_path, seeds_dir)


# ---------------------------------------------------------------------------
# CLI: `migrate` auto-detects VALUES DML and routes to seed generation
# ---------------------------------------------------------------------------

def test_cli_migrate_dry_run_routes_values_dml_to_seed(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path)

    result = cli_runner.invoke(app, ["migrate", str(dml_path), str(tmp_path / "seeds")])

    assert result.exit_code == 0, result.output
    assert "# --- seed csv ---" in result.stdout
    assert "# --- schema.yml ---" in result.stdout
    assert "USG001" in result.stdout


def test_cli_migrate_write_creates_seed_files(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path)
    seeds_dir = tmp_path / "seeds"

    result = cli_runner.invoke(app, ["migrate", str(dml_path), str(seeds_dir), "--write"])

    assert result.exit_code == 0, result.output
    assert (seeds_dir / "app_usage_raw.csv").exists()
    assert (seeds_dir / "schema.yml").exists()


def test_cli_migrate_write_seed_requires_force_to_overwrite(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path)
    seeds_dir = tmp_path / "seeds"
    cli_runner.invoke(app, ["migrate", str(dml_path), str(seeds_dir), "--write"])

    result = cli_runner.invoke(app, ["migrate", str(dml_path), str(seeds_dir), "--write"])

    assert result.exit_code == 1
    assert "already exists" in result.output


def test_cli_migrate_seed_rejects_validate_flag(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml_path, _ = _write_seed_pair(tmp_path)

    result = cli_runner.invoke(
        app, ["migrate", str(dml_path), str(tmp_path / "seeds"), "--validate"]
    )

    assert result.exit_code == 1
    assert "not supported" in result.output


# ---------------------------------------------------------------------------
# CLI: `migrate-sl-folder` routes seed-type dml files to seeds/
# ---------------------------------------------------------------------------

def _make_seed_pipeline_tree(tmp_path: Path) -> Path:
    pipelines = tmp_path / "pipelines"
    seed_dir = pipelines / "seeds/app_usage_raw/sql-scripts"
    seed_dir.mkdir(parents=True)
    (seed_dir / "ddl.app_usage_raw.sql").write_text(APP_USAGE_DDL, encoding="utf-8")
    (seed_dir / "dml.app_usage_raw.sql").write_text(APP_USAGE_DML, encoding="utf-8")
    return pipelines


def test_crawl_pipeline_folder_marks_values_dml_as_seed(tmp_path: Path) -> None:
    pipelines = _make_seed_pipeline_tree(tmp_path)

    entries = crawl_pipeline_folder(pipelines)

    assert len(entries) == 1
    assert entries[0].table_name == "app_usage_raw"
    assert entries[0].is_seed is True


def test_cli_migrate_sl_folder_writes_seed_under_seeds_dir(cli_runner: CliRunner, tmp_path: Path) -> None:
    pipelines = _make_seed_pipeline_tree(tmp_path)
    dbt_project_dir = tmp_path / "dbt_project"

    result = cli_runner.invoke(
        app, ["migrate-sl-folder", str(pipelines), str(dbt_project_dir), "--write"]
    )

    assert result.exit_code == 0, result.output
    assert (dbt_project_dir / "seeds" / "app_usage_raw.csv").exists()
    assert (dbt_project_dir / "seeds" / "schema.yml").exists()
    assert not (dbt_project_dir / "models").exists()
