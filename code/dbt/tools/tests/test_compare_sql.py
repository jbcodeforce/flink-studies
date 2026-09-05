"""Tests for compare_sql.py — seams: normalize_sql, apply_ref_aliases,
compare_migration, format_compare_report.

All expected values are independently derived literals; none recompute
the result the same way the implementation does.
"""

from __future__ import annotations

import pytest

from flink_dbt_migrate.compare_sql import (
    CompareResult,
    apply_ref_aliases,
    compare_migration,
    format_compare_report,
    normalize_sql,
)
from flink_dbt_migrate.parse_dml import parse_dml


# ---------------------------------------------------------------------------
# normalize_sql
# ---------------------------------------------------------------------------


def test_normalize_strips_trailing_semicolon() -> None:
    assert normalize_sql("SELECT 1;") == "select 1"


def test_normalize_collapses_whitespace() -> None:
    assert normalize_sql("SELECT  a,\n  b  FROM  t") == "select a,b from t"


def test_normalize_removes_line_comments() -> None:
    sql = "SELECT a -- this is a\nFROM t -- and this"
    assert normalize_sql(sql) == "select a from t"


def test_normalize_lowercases() -> None:
    assert normalize_sql("SELECT A FROM T") == "select a from t"


def test_normalize_strips_spaces_around_parens_and_commas() -> None:
    # parens and commas must have no surrounding spaces after normalisation
    result = normalize_sql("COALESCE( a , b )")
    assert result == "coalesce(a,b)"


def test_normalize_replaces_not_equal_operator() -> None:
    assert normalize_sql("WHERE a != b") == "where a <> b"


def test_normalize_empty_input_returns_empty() -> None:
    assert normalize_sql("") == ""


def test_normalize_comment_only_lines_are_dropped() -> None:
    sql = "-- only a comment\nSELECT 1"
    assert normalize_sql(sql) == "select 1"


# ---------------------------------------------------------------------------
# apply_ref_aliases
# ---------------------------------------------------------------------------


def test_apply_ref_aliases_rewrites_source_call() -> None:
    sql = "SELECT * FROM {{ source('cc_flink', 'orders') }}"
    # source() calls are always collapsed to the bare table name (second arg)
    result = apply_ref_aliases(sql, {})
    assert result == "SELECT * FROM orders"


def test_apply_ref_aliases_rewrites_compiled_relation_name() -> None:
    sql = "SELECT * FROM `prod`.`public`.`d04_orders`"
    aliases = {"`prod`.`public`.`d04_orders`": "orders", "d04_orders": "orders"}
    result = apply_ref_aliases(sql, aliases)
    assert "orders" in result
    assert "d04_orders" not in result


def test_apply_ref_aliases_longer_key_wins_over_shorter() -> None:
    # Both "schema.table" and "table" map to source names; the longer pattern
    # should be replaced first so the shorter one does not partially corrupt it.
    sql = "FROM `s`.`t` JOIN t"
    aliases = {"`s`.`t`": "parent", "t": "parent"}
    result = apply_ref_aliases(sql, aliases)
    # Both occurrences should have been replaced without leaving backtick artefacts
    assert "`s`.`t`" not in result


def test_apply_ref_aliases_leaves_unrelated_text_unchanged() -> None:
    sql = "SELECT customer_id FROM orders"
    result = apply_ref_aliases(sql, {"other_table": "src"})
    assert result == sql


def test_apply_ref_aliases_empty_aliases_only_strips_source_calls() -> None:
    sql = "FROM {{ source('grp', 'events') }}"
    result = apply_ref_aliases(sql, {})
    assert result == "FROM events"


# ---------------------------------------------------------------------------
# compare_migration
# ---------------------------------------------------------------------------


def _make_dml(body: str, target: str = "out") -> object:
    return parse_dml(f"INSERT INTO {target}\n{body}")


def test_compare_migration_identical_bodies_pass() -> None:
    body = "SELECT id, name FROM customers"
    dml = _make_dml(body)
    result = compare_migration(dml, body)

    assert result.body_match is True
    assert result.body_diff == ""


def test_compare_migration_whitespace_difference_is_ignored() -> None:
    source_body = "SELECT  id,\n  name  FROM  customers"
    compiled_sql = "SELECT id, name FROM customers"
    dml = _make_dml(source_body)
    result = compare_migration(dml, compiled_sql)

    assert result.body_match is True


def test_compare_migration_comment_difference_is_ignored() -> None:
    source_body = "SELECT id -- primary key\nFROM customers"
    compiled_sql = "SELECT id FROM customers"
    dml = _make_dml(source_body)
    result = compare_migration(dml, compiled_sql)

    assert result.body_match is True


def test_compare_migration_semantic_difference_fails() -> None:
    source_body = "SELECT id, name FROM customers"
    compiled_sql = "SELECT id FROM customers"  # 'name' column removed
    dml = _make_dml(source_body)
    result = compare_migration(dml, compiled_sql)

    assert result.body_match is False
    assert result.body_diff != ""


def test_compare_migration_diff_is_unified_format() -> None:
    dml = _make_dml("SELECT a FROM t")
    result = compare_migration(dml, "SELECT b FROM t")

    assert result.body_match is False
    assert "---" in result.body_diff or "+++" in result.body_diff


def test_compare_migration_reconstructed_insert_contains_target_and_body() -> None:
    body = "SELECT id FROM customers"
    dml = _make_dml(body, target="output_table")
    result = compare_migration(dml, body)

    assert "INSERT INTO output_table" in result.reconstructed_insert
    assert "SELECT id FROM customers" in result.reconstructed_insert


def test_compare_migration_source_insert_contains_leading_comments() -> None:
    sql = "-- source comment\nINSERT INTO out\nSELECT 1"
    dml = parse_dml(sql)
    result = compare_migration(dml, "SELECT 1")

    assert "-- source comment" in result.source_insert


def test_compare_migration_ref_alias_normalises_compiled_table_names() -> None:
    # When the compiled SQL uses a plain alias key (no surrounding backticks),
    # apply_ref_aliases replaces it via the word-boundary pattern so the
    # normalised bodies match.
    source_body = "SELECT id FROM orders"
    compiled_sql = "SELECT id FROM compiled_orders"
    # alias maps the compiled relation name back to the source table name
    aliases = {"compiled_orders": "orders"}
    dml = _make_dml(source_body)
    result = compare_migration(dml, compiled_sql, ref_aliases=aliases)

    assert result.body_match is True


def test_compare_migration_source_call_normalises_to_table_name() -> None:
    source_body = "SELECT id FROM orders"
    compiled_sql = "SELECT id FROM {{ source('cc_flink', 'orders') }}"
    dml = _make_dml(source_body)
    result = compare_migration(dml, compiled_sql)

    assert result.body_match is True


def test_compare_migration_insert_match_true_when_bodies_match() -> None:
    body = "SELECT x FROM t"
    dml = _make_dml(body, target="dest")
    result = compare_migration(dml, body)

    assert result.insert_match is True


def test_compare_migration_insert_match_false_when_bodies_differ() -> None:
    dml = _make_dml("SELECT a FROM t", target="dest")
    result = compare_migration(dml, "SELECT b FROM t")

    assert result.insert_match is False


# ---------------------------------------------------------------------------
# format_compare_report
# ---------------------------------------------------------------------------


def test_format_compare_report_pass_contains_validation_passed() -> None:
    result = CompareResult(
        body_match=True,
        body_diff="",
        source_insert="INSERT INTO t\nSELECT 1",
        reconstructed_insert="INSERT INTO t\nSELECT 1",
        insert_match=True,
    )
    report = format_compare_report(result)

    assert "Validation passed" in report
    assert "Reconstructed INSERT INTO t" in report


def test_format_compare_report_pass_shows_line_count() -> None:
    reconstructed = "INSERT INTO orders\nSELECT id\nFROM customers"  # 3 lines
    result = CompareResult(
        body_match=True,
        body_diff="",
        source_insert=reconstructed,
        reconstructed_insert=reconstructed,
        insert_match=True,
    )
    report = format_compare_report(result)

    assert "(3 lines)" in report


def test_format_compare_report_fail_contains_mismatch_header() -> None:
    result = CompareResult(
        body_match=False,
        body_diff="--- source\n+++ compiled\n-a\n+b",
        source_insert="INSERT INTO t\nSELECT a FROM x",
        reconstructed_insert="INSERT INTO t\nSELECT b FROM x",
        insert_match=False,
    )
    report = format_compare_report(result)

    assert "Query body mismatch" in report


def test_format_compare_report_fail_includes_diff() -> None:
    diff = "--- source\n+++ compiled\n-SELECT a\n+SELECT b"
    result = CompareResult(
        body_match=False,
        body_diff=diff,
        source_insert="INSERT INTO t\nSELECT a FROM x",
        reconstructed_insert="INSERT INTO t\nSELECT b FROM x",
        insert_match=False,
    )
    report = format_compare_report(result)

    assert diff in report


def test_format_compare_report_fail_includes_reconstructed_insert() -> None:
    reconstructed = "INSERT INTO t\nSELECT b FROM x"
    result = CompareResult(
        body_match=False,
        body_diff="--- source\n+++ compiled\n-a\n+b",
        source_insert="INSERT INTO t\nSELECT a FROM x",
        reconstructed_insert=reconstructed,
        insert_match=False,
    )
    report = format_compare_report(result)

    assert reconstructed in report
