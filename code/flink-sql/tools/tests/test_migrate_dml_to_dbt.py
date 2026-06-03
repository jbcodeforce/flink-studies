"""Tests for Flink DML → dbt migration."""

from __future__ import annotations

from pathlib import Path

import pytest

from flink_dbt_migrate.emit_model import emit_model_sql
from flink_dbt_migrate.migrate import migrate_dml_to_dbt
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import discover_ddl_path, parse_dml
from flink_dbt_migrate.rewrite_refs import collect_cte_names, rewrite_refs
from flink_dbt_migrate.type_map import flink_type_to_dbt

FLINK_SQL = Path(__file__).resolve().parents[2]
CART_UPDATE = FLINK_SQL / "11-puzzles/cart_update"
ROLLING = FLINK_SQL / "10-windowing/tumble_then_hop_rolling"


def test_parse_dml_cart_line_items() -> None:
    sql = (CART_UPDATE / "dml.build_cart_line_items.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql, source_file="dml.build_cart_line_items.sql")

    assert dml.target_table == "cart_line_items"
    assert dml.body.startswith("SELECT")
    assert "FROM cart_events" in dml.body
    assert "INSERT INTO" not in dml.body


def test_discover_ddl_by_stem() -> None:
    dml_path = ROLLING / "dml.rolling_features.sql"
    ddl_path = discover_ddl_path(str(dml_path), "rolling_features")
    assert ddl_path.endswith("ddl.rolling_features.sql")


def test_parse_ddl_integrated_cart() -> None:
    sql = (CART_UPDATE / "ddl.integrated_cart.sql").read_text(encoding="utf-8")
    ddl = parse_ddl(sql)

    assert ddl.table_name == "integrated_cart"
    assert ddl.distributed_by == "cart_id"
    assert ddl.with_options["changelog.mode"] == "upsert"
    assert len(ddl.columns) == 6
    assert ddl.columns[-1].name == "products"
    assert "ARRAY<" in ddl.columns[-1].flink_type
    assert flink_type_to_dbt("DECIMAL(10, 2)") == "decimal(10, 2)"


def test_rewrite_refs_skips_ctes() -> None:
    body = (ROLLING / "dml.rolling_features.sql").read_text(encoding="utf-8")
    dml = parse_dml(body)
    cte_names = collect_cte_names(dml.body)
    assert cte_names == {"base", "bucket_1h", "agg"}

    rewritten = rewrite_refs(dml.body, cte_names)
    assert "FROM {{ ref('events') }}" in rewritten
    assert "TABLE base" in rewritten
    assert "FROM agg" in rewritten
    assert "{{ ref('agg') }}" not in rewritten


def test_rewrite_refs_join_tables() -> None:
    sql = (CART_UPDATE / "dml.integrated_cart.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    rewritten = rewrite_refs(dml.body, collect_cte_names(dml.body))

    assert "FROM {{ ref('cart_line_items') }} AS c" in rewritten
    assert "JOIN {{ ref('products') }} AS p" in rewritten


def test_migrate_rolling_features_golden(tmp_path: Path) -> None:
    result = migrate_dml_to_dbt(
        ROLLING / "dml.rolling_features.sql",
        tmp_path,
    )

    assert result.model_name == "rolling_features"
    assert "materialized='streaming_table'" in result.model_sql
    assert "distributed_by='user_id'" in result.model_sql
    assert "'changelog.mode': 'upsert'" in result.model_sql
    assert "FROM {{ ref('events') }}" in result.model_sql
    assert "Migrated from dml.rolling_features.sql" in result.model_sql

    assert "name: rolling_features" in result.schema_yml
    assert "data_type: string" in result.schema_yml
    assert "data_type: timestamp(3)" in result.schema_yml
    assert "data_type: decimal(20, 2)" in result.schema_yml


def test_migrate_cart_line_items(tmp_path: Path) -> None:
    result = migrate_dml_to_dbt(
        CART_UPDATE / "dml.build_cart_line_items.sql",
        tmp_path,
    )

    assert result.model_name == "cart_line_items"
    assert "FROM {{ ref('cart_events') }}" in result.model_sql
    assert "distributed_by='cart_id, product_id'" in result.model_sql


def test_reject_ctas() -> None:
    with pytest.raises(ValueError, match="CTAS"):
        parse_dml("CREATE TABLE t AS SELECT 1")


def test_reject_insert_values() -> None:
    with pytest.raises(ValueError, match="VALUES"):
        parse_dml("INSERT INTO t VALUES (1)")


def test_emit_model_with_ref_override() -> None:
    dml = parse_dml("INSERT INTO out SELECT * FROM events")
    ddl = parse_ddl(
        (ROLLING / "ddl.rolling_features.sql").read_text(encoding="utf-8")
    )
    sql = emit_model_sql(
        dml,
        ddl,
        ref_overrides={"events": "src_events"},
    )
    assert "{{ ref('src_events') }}" in sql
