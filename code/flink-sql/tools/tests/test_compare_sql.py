"""Tests for SQL comparison between source DML and compiled dbt models."""

from __future__ import annotations

from pathlib import Path

from flink_dbt_migrate.compare_sql import (
    apply_ref_aliases,
    compare_migration,
    format_compare_report,
    normalize_sql,
)
from flink_dbt_migrate.parse_dml import parse_dml

FLINK_SQL = Path(__file__).resolve().parents[2]
ROLLING = FLINK_SQL / "10-windowing/tumble_then_hop_rolling"


def test_normalize_sql_strips_comments_and_whitespace() -> None:
    sql = "-- header\nSELECT  a\nFROM  t WHERE x != 1;"
    assert normalize_sql(sql) == "select a from t where x <> 1"


def test_apply_ref_aliases_replaces_compiled_names() -> None:
    sql = "SELECT * FROM `env.schema.events` e JOIN events x"
    aliases = {"env.schema.events": "events", "events": "events"}
    result = apply_ref_aliases(sql, aliases)
    assert "`env.schema.events`" not in result
    assert "from events e" in result.lower()
    print(result)


def test_compare_migration_body_match_rolling_features() -> None:
    source_text = (ROLLING / "dml.rolling_features.sql").read_text(encoding="utf-8")
    source_dml = parse_dml(source_text)

    compiled_sql = source_dml.body.replace("FROM events", "FROM `catalog.schema.events`")

    result = compare_migration(
        source_dml,
        compiled_sql,
        ref_aliases={"catalog.schema.events": "events"},
    )

    assert result.body_match is True
    assert result.insert_match is True
    assert "INSERT INTO rolling_features" in result.reconstructed_insert
    assert "Validation passed" in format_compare_report(result)


def test_compare_migration_body_mismatch_produces_diff() -> None:
    source_dml = parse_dml("INSERT INTO out SELECT id FROM events")
    compiled_sql = "SELECT id, extra_col FROM events"

    result = compare_migration(source_dml, compiled_sql)

    assert result.body_match is False
    assert result.insert_match is False
    assert result.body_diff
    report = format_compare_report(result)
    assert "# Query body mismatch" in report
    assert "# Reconstructed INSERT (for inspection)" in report
