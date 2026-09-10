"""Tests for Flink DML → dbt migration."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest
from typer.testing import CliRunner

from flink_dbt_migrate.migrate_dml_to_dbt import app

# tests/ → tools/ → dbt/ → code/ → repo root, then into code/flink-sql
tests_path =  Path(__file__).resolve().parent # current tests folder

FLINK_SQL = Path(__file__).resolve().parents[3] / "flink-sql"
CART_UPDATE = FLINK_SQL / "11-puzzles/cart_update"
BASIC_PATH = FLINK_SQL / "00-basic-sql" / "cc-flink"
ROLLING = FLINK_SQL / "10-windowing/tumble_then_hop_rolling"
JOINS_CC_FLINK = FLINK_SQL / "04-joins/cc-flink"
JOINS_CC_DBT = FLINK_SQL / "04-joins/cc_dbt"
JOIN_04 = FLINK_SQL / "04-joins"


@pytest.fixture
def cli_runner() -> CliRunner:
    return CliRunner()


def test_cli_dry_run(cli_runner: CliRunner) -> None:
    dbt_project_path = tests_path / "dbt_out"
    target_path : Path = dbt_project_path / "models" / "employees"
    result = cli_runner.invoke(
        app,
        ["migrate-one-file", str(BASIC_PATH / "dml.employee_count.sql"), str(target_path), "--dbt-project-dir", dbt_project_path],
         catch_exceptions=False, 
    )
    print(result.stdout)
    assert result.exit_code == 0, f"CLI invocation failed (exit_code={result.exit_code}):\n{result.output}"
    assert "# --- model ---" in result.stdout
    assert "materialized='streaming_table'" in result.stdout
    assert "# --- schema.yml ---" in result.stdout
    assert "name: employee" in result.stdout


def test_cli_write(cli_runner: CliRunner) -> None:
    dbt_project_path = tests_path / "dbt_out"
    target_path : Path = dbt_project_path / "models" / "employee"
   
    result = cli_runner.invoke(
        app,
        ["migrate-one-file", str(BASIC_PATH / "dml.employee_count.sql"), str(target_path), "--dbt-project-dir", dbt_project_path, "--write", "--force"],
    )
    print(result.stdout)
    assert result.exit_code == 0, f"CLI invocation failed (exit_code={result.exit_code}):\n{result.output}"
    assert (target_path / "employee_count.sql").exists()
    assert (target_path / "schema.yml").exists()
    assert "Wrote" in result.stdout

