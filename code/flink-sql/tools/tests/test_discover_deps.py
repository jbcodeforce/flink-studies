"""Tests for upstream dependency discovery."""

from __future__ import annotations

from pathlib import Path

import pytest

from flink_dbt_migrate.discover_deps import (
    collect_upstream_tables,
    default_source_name,
    discover_upstream_ddl,
    find_dbt_model,
    resolve_upstream_deps,
)
from flink_dbt_migrate.parse_dml import parse_dml
from flink_dbt_migrate.rewrite_refs import collect_cte_names

FLINK_SQL = Path(__file__).resolve().parents[2]
JOINS_CC_FLINK = FLINK_SQL / "04-joins/cc-flink"
JOINS_CC_DBT = FLINK_SQL / "04-joins/cc_dbt"


def test_collect_upstream_tables_enriched_orders() -> None:
    sql = (JOINS_CC_FLINK / "dml.enriched_orders.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    cte_names = collect_cte_names(dml.body)
    tables = collect_upstream_tables(dml.body, cte_names)
    assert tables == ["d04_orders", "d04_products"]


def test_discover_upstream_ddl_prefers_non_wm_variant() -> None:
    ddl_path = discover_upstream_ddl(JOINS_CC_FLINK, "d04_orders")
    assert ddl_path.name == "ddl.orders.sql"


def test_discover_upstream_ddl_products() -> None:
    ddl_path = discover_upstream_ddl(JOINS_CC_FLINK, "d04_products")
    assert ddl_path.name == "ddl.products.sql"


def test_find_dbt_model_missing() -> None:
    assert find_dbt_model(JOINS_CC_DBT, "d04_orders") is None


def test_default_source_name() -> None:
    assert default_source_name(JOINS_CC_FLINK) == "cc_flink"


def test_resolve_upstream_deps_classifies_sources() -> None:
    sql = (JOINS_CC_FLINK / "dml.enriched_orders.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    deps = resolve_upstream_deps(
        JOINS_CC_FLINK,
        JOINS_CC_DBT,
        dml,
        source_name="cc_flink",
    )
    assert [dep.table_name for dep in deps] == ["d04_orders", "d04_products"]
    assert all(dep.resolution == "source" for dep in deps)
    assert all(dep.source_name == "cc_flink" for dep in deps)
    assert all(dep.ddl_path is not None for dep in deps)


def test_resolve_upstream_deps_ref_override() -> None:
    sql = (JOINS_CC_FLINK / "dml.enriched_orders.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    deps = resolve_upstream_deps(
        JOINS_CC_FLINK,
        JOINS_CC_DBT,
        dml,
        ref_overrides={"d04_orders": "orders_model"},
    )
    orders = deps[0]
    assert orders.resolution == "ref"
    assert orders.ref_model == "orders_model"


def test_resolve_upstream_deps_no_sources_uses_ref() -> None:
    sql = (JOINS_CC_FLINK / "dml.enriched_orders.sql").read_text(encoding="utf-8")
    dml = parse_dml(sql)
    deps = resolve_upstream_deps(
        JOINS_CC_FLINK,
        JOINS_CC_DBT,
        dml,
        resolve_sources=False,
    )
    assert all(dep.resolution == "ref" for dep in deps)


def test_discover_upstream_ddl_missing_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="No DDL file found"):
        discover_upstream_ddl(tmp_path, "missing_table")
