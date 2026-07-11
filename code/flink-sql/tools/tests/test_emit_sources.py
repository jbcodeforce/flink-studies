"""Tests for sources.yaml emission."""

from __future__ import annotations

from pathlib import Path

from flink_dbt_migrate.discover_deps import resolve_upstream_deps
from flink_dbt_migrate.emit_sources import (
    build_source_table_entry,
    emit_sources_yml,
    load_sources_yml,
    merge_sources_yml,
)
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import parse_dml

FLINK_SQL = Path(__file__).resolve().parents[2]
JOINS_CC_FLINK = FLINK_SQL / "04-joins/cc-flink"
JOINS_CC_DBT = FLINK_SQL / "04-joins/cc_dbt"


def test_build_source_table_entry_from_orders_ddl() -> None:
    ddl = parse_ddl((JOINS_CC_FLINK / "ddl.orders.sql").read_text(encoding="utf-8"))
    entry = build_source_table_entry("d04_orders", ddl)
    assert entry["name"] == "d04_orders"
    assert entry["identifier"] == "d04_orders"
    assert entry["columns"][0] == {"name": "id", "data_type": "int"}


def test_merge_sources_yml_into_empty(tmp_path: Path) -> None:
    data = load_sources_yml(tmp_path / "sources.yaml")
    merged = merge_sources_yml(
        data,
        "cc_flink",
        [{"name": "d04_orders", "identifier": "d04_orders", "columns": []}],
    )
    assert merged["sources"][0]["name"] == "cc_flink"
    assert merged["sources"][0]["tables"][0]["name"] == "d04_orders"


def test_merge_sources_yml_does_not_duplicate(tmp_path: Path) -> None:
    path = tmp_path / "sources.yaml"
    path.write_text(
        "version: 2\nsources:\n  - name: cc_flink\n    tables:\n      - name: d04_orders\n        identifier: d04_orders\n",
        encoding="utf-8",
    )
    data = load_sources_yml(path)
    merged = merge_sources_yml(
        data,
        "cc_flink",
        [{"name": "d04_orders", "identifier": "d04_orders", "columns": []}],
    )
    assert len(merged["sources"][0]["tables"]) == 1


def test_emit_sources_yml_for_enriched_orders(tmp_path: Path) -> None:
    sql = (JOINS_CC_FLINK / "dml.enriched_orders.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    deps = resolve_upstream_deps(JOINS_CC_FLINK, JOINS_CC_DBT, dml, source_name="cc_flink")
    models_dir = tmp_path / "models"
    models_dir.mkdir()

    content = emit_sources_yml(models_dir, "cc_flink", deps)
    assert content is not None
    assert "name: cc_flink" in content
    assert "name: d04_orders" in content
    assert "name: d04_products" in content
    assert "data_type: int" in content
