"""Unit tests for dbt_element_mgr — model SQL, schema.yml, seed CSV, and sources.yaml."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from flink_dbt_migrate.dbt_element_mgr import (
    SCHEMA_YML_NAME,
    SOURCES_YML_NAME,
    build_model_schema_entry,
    build_seed_schema_entry,
    build_source_table_entry,
    dump_schema_yml,
    dump_seed_schema_yml,
    dump_sources_yml,
    emit_model_sql,
    emit_schema_yml,
    emit_seed_csv,
    emit_seed_schema_yml,
    emit_sources_yml,
    format_config_block,
    load_schema_yml,
    load_seed_schema_yml,
    load_sources_yml,
    merge_model_schema,
    merge_seed_schema,
    merge_sources_yml,
    model_entry_index,
    seed_entry_index,
    source_entry_index,
    source_table_index,
)
from flink_dbt_migrate.discover_deps import UpstreamDep
from flink_dbt_migrate.flink_sql_processor import DdlColumn, DdlTable, DmlStatement

# ---------------------------------------------------------------------------
# Shared DDL / DML fixtures
# ---------------------------------------------------------------------------

ORDERS_DDL_SQL = """\
CREATE TABLE orders (
    order_id STRING,
    customer_id STRING,
    amount DECIMAL(10, 2),
    created_at TIMESTAMP(3)
) DISTRIBUTED BY HASH(order_id) INTO 1 BUCKETS WITH (
    'changelog.mode' = 'append',
    'value.format' = 'avro-registry'
)
"""

ORDERS_DML_SQL = """\
INSERT INTO orders
SELECT o.order_id, o.customer_id, o.amount, o.created_at
FROM raw_orders o
JOIN customers c ON o.customer_id = c.id
"""

SIMPLE_DDL_SQL = """\
CREATE TABLE events (
    event_id STRING,
    event_type STRING
)
"""


def _make_ddl(
    table_name: str = "orders",
    columns: list[tuple[str, str]] | None = None,
    distributed_by: str | None = "order_id",
    with_options: dict[str, str] | None = None,
) -> DdlTable:
    cols = columns or [("order_id", "STRING"), ("amount", "DECIMAL(10, 2)")]
    return DdlTable(
        table_name=table_name,
        columns=[DdlColumn(name=n, flink_type=t) for n, t in cols],
        distributed_by=distributed_by,
        with_options=with_options or {},
    )


def _make_dml(
    body: str = "SELECT order_id FROM raw_orders",
    source_file: str = "dml.orders.sql",
    leading_comments: str = "",
) -> DmlStatement:
    return DmlStatement(
        target_table="orders",
        body=body,
        leading_comments=leading_comments,
        with_options={},
        source_file=source_file,
    )


# ---------------------------------------------------------------------------
# format_config_block
# ---------------------------------------------------------------------------


def test_format_config_block_minimal() -> None:
    ddl = _make_ddl(distributed_by=None, with_options={})
    result = format_config_block(ddl)

    assert "materialized='streaming_table'" in result
    assert "distributed_by" not in result
    assert "with=" not in result


def test_format_config_block_custom_materialized() -> None:
    ddl = _make_ddl(distributed_by=None, with_options={})
    result = format_config_block(ddl, materialized="incremental")

    assert "materialized='incremental'" in result


def test_format_config_block_includes_distributed_by() -> None:
    ddl = _make_ddl(distributed_by="order_id")
    result = format_config_block(ddl)

    assert "distributed_by='order_id'" in result


def test_format_config_block_includes_with_options() -> None:
    ddl = _make_ddl(with_options={"changelog.mode": "append", "value.format": "avro-registry"})
    result = format_config_block(ddl)

    assert "'changelog.mode': 'append'" in result
    assert "'value.format': 'avro-registry'" in result
    assert "with={" in result


def test_format_config_block_last_with_option_has_no_trailing_comma() -> None:
    ddl = _make_ddl(with_options={"a": "1", "b": "2"})
    result = format_config_block(ddl)

    lines = result.splitlines()
    last_option_line = [l for l in lines if "'b'" in l][0]
    assert not last_option_line.rstrip().endswith(",")


# ---------------------------------------------------------------------------
# emit_model_sql
# ---------------------------------------------------------------------------


def test_emit_model_sql_includes_config_and_body() -> None:
    ddl = _make_ddl()
    dml = _make_dml()
    result = emit_model_sql(dml, ddl)

    assert "{{ config(" in result
    assert "SELECT order_id FROM" in result


def test_emit_model_sql_appends_migration_note_from_dml_source_file() -> None:
    ddl = _make_ddl()
    dml = _make_dml(source_file="dml.orders.sql")
    result = emit_model_sql(dml, ddl)

    assert "-- Migrated from dml.orders.sql" in result


def test_emit_model_sql_source_filename_overrides_dml_source_file() -> None:
    ddl = _make_ddl()
    dml = _make_dml(source_file="original.sql")
    result = emit_model_sql(dml, ddl, source_filename="override.sql")

    assert "-- Migrated from override.sql" in result
    assert "original.sql" not in result


def test_emit_model_sql_no_migration_note_when_no_source() -> None:
    ddl = _make_ddl()
    dml = _make_dml(source_file="")
    result = emit_model_sql(dml, ddl)

    assert "-- Migrated from" not in result


def test_emit_model_sql_includes_leading_comments() -> None:
    ddl = _make_ddl()
    dml = _make_dml(leading_comments="-- author: alice")
    result = emit_model_sql(dml, ddl)

    assert "-- author: alice" in result


def test_emit_model_sql_rewrites_ref_table() -> None:
    ddl = _make_ddl()
    body = "SELECT * FROM raw_orders"
    dml = _make_dml(body=body, source_file="")
    dep = UpstreamDep(
        table_name="raw_orders",
        ddl_path=None,
        ddl=None,
        resolution="ref",
        ref_model="raw_orders",
    )
    result = emit_model_sql(dml, ddl, upstream_deps=[dep])

    assert "{{ ref('raw_orders') }}" in result


def test_emit_model_sql_rewrites_source_table() -> None:
    ddl = _make_ddl()
    body = "SELECT * FROM raw_orders"
    dml = _make_dml(body=body, source_file="")
    dep = UpstreamDep(
        table_name="raw_orders",
        ddl_path=None,
        ddl=None,
        resolution="source",
        source_name="kafka_sources",
    )
    result = emit_model_sql(dml, ddl, upstream_deps=[dep])

    assert "{{ source('kafka_sources', 'raw_orders') }}" in result


def test_emit_model_sql_ends_with_newline() -> None:
    ddl = _make_ddl()
    dml = _make_dml()
    result = emit_model_sql(dml, ddl)

    assert result.endswith("\n")


# ---------------------------------------------------------------------------
# build_model_schema_entry
# ---------------------------------------------------------------------------


def test_build_model_schema_entry_uses_source_filename_as_description() -> None:
    ddl = _make_ddl()
    entry = build_model_schema_entry("orders", ddl, source_filename="dml.orders.sql")

    assert entry["description"] == "Migrated from dml.orders.sql"


def test_build_model_schema_entry_default_description() -> None:
    ddl = _make_ddl()
    entry = build_model_schema_entry("orders", ddl)

    assert "orders" in entry["description"]


def test_build_model_schema_entry_maps_column_types() -> None:
    ddl = _make_ddl(columns=[("id", "STRING"), ("amount", "DECIMAL(10, 2)")])
    entry = build_model_schema_entry("orders", ddl)

    col_map = {c["name"]: c["data_type"] for c in entry["columns"]}
    assert col_map["id"] == "VARCHAR"
    assert col_map["amount"] == "DECIMAL(10, 2)"


# ---------------------------------------------------------------------------
# load_schema_yml / dump_schema_yml / model_entry_index
# ---------------------------------------------------------------------------


def test_load_schema_yml_returns_empty_template_when_missing(tmp_path: Path) -> None:
    data = load_schema_yml(tmp_path / "schema.yml")

    assert data == {"version": 2, "models": []}


def test_load_schema_yml_reads_existing_file(tmp_path: Path) -> None:
    schema_path = tmp_path / "schema.yml"
    schema_path.write_text("version: 2\nmodels:\n- name: foo\n", encoding="utf-8")

    data = load_schema_yml(schema_path)

    assert data["models"][0]["name"] == "foo"


def test_model_entry_index_returns_none_when_absent() -> None:
    data = {"models": [{"name": "other"}]}
    assert model_entry_index(data, "orders") is None


def test_model_entry_index_returns_correct_position() -> None:
    data = {"models": [{"name": "alpha"}, {"name": "orders"}]}
    assert model_entry_index(data, "orders") == 1


def test_dump_schema_yml_produces_valid_yaml() -> None:
    data = {"version": 2, "models": [{"name": "orders", "columns": []}]}
    text = dump_schema_yml(data)

    parsed = yaml.safe_load(text)
    assert parsed["models"][0]["name"] == "orders"


# ---------------------------------------------------------------------------
# merge_model_schema
# ---------------------------------------------------------------------------


def test_merge_model_schema_appends_new_entry() -> None:
    data = {"version": 2, "models": []}
    ddl = _make_ddl()
    entry = build_model_schema_entry("orders", ddl)
    merge_model_schema(data, entry)

    assert len(data["models"]) == 1
    assert data["models"][0]["name"] == "orders"


def test_merge_model_schema_sorted_alphabetically() -> None:
    data = {"version": 2, "models": []}
    for name in ("zeta", "alpha", "mu"):
        merge_model_schema(data, {"name": name, "columns": []})

    names = [m["name"] for m in data["models"]]
    assert names == sorted(names)


def test_merge_model_schema_preserves_description_without_force() -> None:
    data = {
        "version": 2,
        "models": [{"name": "orders", "description": "hand-written", "columns": []}],
    }
    ddl = _make_ddl()
    entry = build_model_schema_entry("orders", ddl, source_filename="dml.orders.sql")
    merge_model_schema(data, entry, force=False)

    assert data["models"][0]["description"] == "hand-written"


def test_merge_model_schema_adds_new_column_without_force() -> None:
    data = {
        "version": 2,
        "models": [
            {
                "name": "orders",
                "description": "existing",
                "columns": [{"name": "order_id", "data_type": "VARCHAR"}],
            }
        ],
    }
    ddl = _make_ddl(columns=[("order_id", "STRING"), ("amount", "DECIMAL(10, 2)")])
    entry = build_model_schema_entry("orders", ddl)
    merge_model_schema(data, entry, force=False)

    col_names = [c["name"] for c in data["models"][0]["columns"]]
    assert "amount" in col_names


def test_merge_model_schema_force_replaces_entry() -> None:
    data = {
        "version": 2,
        "models": [{"name": "orders", "description": "stale", "columns": []}],
    }
    ddl = _make_ddl()
    entry = build_model_schema_entry("orders", ddl, source_filename="new.sql")
    merge_model_schema(data, entry, force=True)

    assert data["models"][0]["description"] == "Migrated from new.sql"


# ---------------------------------------------------------------------------
# emit_schema_yml (integration)
# ---------------------------------------------------------------------------


def test_emit_schema_yml_creates_valid_output(tmp_path: Path) -> None:
    ddl = _make_ddl()
    text = emit_schema_yml(tmp_path, "orders", ddl, source_filename="dml.orders.sql")

    data = yaml.safe_load(text)
    assert data["version"] == 2
    assert data["models"][0]["name"] == "orders"


def test_emit_schema_yml_merges_into_existing_file(tmp_path: Path) -> None:
    existing = {"version": 2, "models": [{"name": "alpha", "columns": []}]}
    (tmp_path / SCHEMA_YML_NAME).write_text(
        yaml.safe_dump(existing), encoding="utf-8"
    )
    ddl = _make_ddl()
    text = emit_schema_yml(tmp_path, "orders", ddl)

    data = yaml.safe_load(text)
    names = [m["name"] for m in data["models"]]
    assert "alpha" in names
    assert "orders" in names


# ---------------------------------------------------------------------------
# emit_seed_csv
# ---------------------------------------------------------------------------


def test_emit_seed_csv_header_and_rows() -> None:
    text = emit_seed_csv(["id", "name"], [["1", "alice"], ["2", "bob"]])

    lines = text.splitlines()
    assert lines[0] == "id,name"
    assert lines[1] == "1,alice"
    assert lines[2] == "2,bob"


def test_emit_seed_csv_none_becomes_empty_string() -> None:
    text = emit_seed_csv(["a", "b"], [[None, "x"]])

    assert text.splitlines()[1] == ",x"


def test_emit_seed_csv_quotes_values_containing_commas() -> None:
    text = emit_seed_csv(["a"], [["val, ue"]])

    assert '"val, ue"' in text


def test_emit_seed_csv_single_column_no_trailing_newline_issue() -> None:
    text = emit_seed_csv(["col"], [["v"]])

    assert text.endswith("\n")


# ---------------------------------------------------------------------------
# build_seed_schema_entry
# ---------------------------------------------------------------------------


def test_build_seed_schema_entry_source_filename_description() -> None:
    ddl = _make_ddl()
    entry = build_seed_schema_entry("orders", ddl, source_filename="dml.orders.sql")

    assert entry["description"] == "Migrated from dml.orders.sql"


def test_build_seed_schema_entry_default_description() -> None:
    ddl = _make_ddl()
    entry = build_seed_schema_entry("orders", ddl)

    assert "orders" in entry["description"]


def test_build_seed_schema_entry_column_types_mapped() -> None:
    ddl = _make_ddl(columns=[("id", "STRING"), ("score", "DECIMAL(5, 2)")])
    entry = build_seed_schema_entry("t", ddl)

    assert entry["config"]["column_types"]["id"] == "VARCHAR"
    assert entry["config"]["column_types"]["score"] == "DECIMAL(5, 2)"


def test_build_seed_schema_entry_includes_meta_when_with_options_present() -> None:
    ddl = _make_ddl(with_options={"key.format": "avro-registry"})
    entry = build_seed_schema_entry("t", ddl)

    assert entry["meta"]["flink_ddl_with_options"]["key.format"] == "avro-registry"


def test_build_seed_schema_entry_no_meta_when_no_with_options() -> None:
    ddl = _make_ddl(with_options={})
    entry = build_seed_schema_entry("t", ddl)

    assert "meta" not in entry


# ---------------------------------------------------------------------------
# load_seed_schema_yml / seed_entry_index / merge_seed_schema
# ---------------------------------------------------------------------------


def test_load_seed_schema_yml_returns_empty_template_when_missing(tmp_path: Path) -> None:
    data = load_seed_schema_yml(tmp_path / "schema.yml")

    assert data == {"version": 2, "seeds": []}


def test_seed_entry_index_returns_none_for_absent_seed() -> None:
    data = {"seeds": [{"name": "other"}]}
    assert seed_entry_index(data, "orders") is None


def test_seed_entry_index_returns_correct_position() -> None:
    data = {"seeds": [{"name": "alpha"}, {"name": "orders"}]}
    assert seed_entry_index(data, "orders") == 1


def test_merge_seed_schema_appends_new_seed() -> None:
    data = {"version": 2, "seeds": []}
    ddl = _make_ddl()
    entry = build_seed_schema_entry("orders", ddl)
    merge_seed_schema(data, entry)

    assert data["seeds"][0]["name"] == "orders"


def test_merge_seed_schema_sorted_alphabetically() -> None:
    data = {"version": 2, "seeds": []}
    for name in ("zeta", "alpha", "mu"):
        merge_seed_schema(
            data,
            {"name": name, "description": "", "config": {"column_types": {}}},
        )

    names = [s["name"] for s in data["seeds"]]
    assert names == sorted(names)


def test_merge_seed_schema_preserves_description_without_force() -> None:
    data = {
        "version": 2,
        "seeds": [
            {
                "name": "orders",
                "description": "hand-written",
                "config": {"column_types": {}},
            }
        ],
    }
    ddl = _make_ddl()
    entry = build_seed_schema_entry("orders", ddl, source_filename="dml.orders.sql")
    merge_seed_schema(data, entry, force=False)

    assert data["seeds"][0]["description"] == "hand-written"


def test_merge_seed_schema_adds_new_column_type_without_force() -> None:
    data = {
        "version": 2,
        "seeds": [
            {
                "name": "orders",
                "description": "x",
                "config": {"column_types": {"order_id": "VARCHAR"}},
            }
        ],
    }
    ddl = _make_ddl(columns=[("order_id", "STRING"), ("amount", "DECIMAL(10, 2)")])
    entry = build_seed_schema_entry("orders", ddl)
    merge_seed_schema(data, entry, force=False)

    assert data["seeds"][0]["config"]["column_types"]["amount"] == "DECIMAL(10, 2)"


def test_merge_seed_schema_force_replaces_entry() -> None:
    data = {
        "version": 2,
        "seeds": [
            {
                "name": "orders",
                "description": "stale",
                "config": {"column_types": {}},
            }
        ],
    }
    ddl = _make_ddl()
    entry = build_seed_schema_entry("orders", ddl, source_filename="new.sql")
    merge_seed_schema(data, entry, force=True)

    assert data["seeds"][0]["description"] == "Migrated from new.sql"


def test_merge_seed_schema_preserves_meta_without_force() -> None:
    data = {
        "version": 2,
        "seeds": [
            {
                "name": "orders",
                "description": "x",
                "config": {"column_types": {}},
                "meta": {"flink_ddl_with_options": {"old": "val"}},
            }
        ],
    }
    ddl = _make_ddl(with_options={"new": "opt"})
    entry = build_seed_schema_entry("orders", ddl)
    merge_seed_schema(data, entry, force=False)

    assert data["seeds"][0]["meta"]["flink_ddl_with_options"]["old"] == "val"


# ---------------------------------------------------------------------------
# emit_seed_schema_yml (integration)
# ---------------------------------------------------------------------------


def test_emit_seed_schema_yml_creates_valid_output(tmp_path: Path) -> None:
    ddl = _make_ddl()
    text = emit_seed_schema_yml(tmp_path, "orders", ddl, source_filename="dml.orders.sql")

    data = yaml.safe_load(text)
    assert data["version"] == 2
    assert data["seeds"][0]["name"] == "orders"


def test_emit_seed_schema_yml_merges_into_existing_file(tmp_path: Path) -> None:
    existing = {
        "version": 2,
        "seeds": [{"name": "alpha", "description": "x", "config": {"column_types": {}}}],
    }
    (tmp_path / "schema.yml").write_text(yaml.safe_dump(existing), encoding="utf-8")
    ddl = _make_ddl()
    text = emit_seed_schema_yml(tmp_path, "orders", ddl)

    data = yaml.safe_load(text)
    names = [s["name"] for s in data["seeds"]]
    assert "alpha" in names
    assert "orders" in names


# ---------------------------------------------------------------------------
# build_source_table_entry
# ---------------------------------------------------------------------------


def test_build_source_table_entry_name_and_identifier() -> None:
    ddl = _make_ddl(table_name="raw_orders")
    entry = build_source_table_entry("raw_orders", ddl)

    assert entry["name"] == "raw_orders"
    assert entry["identifier"] == "raw_orders"


def test_build_source_table_entry_custom_identifier() -> None:
    ddl = _make_ddl(table_name="raw_orders")
    entry = build_source_table_entry("raw_orders", ddl, identifier="kafka_raw_orders")

    assert entry["identifier"] == "kafka_raw_orders"


def test_build_source_table_entry_columns_mapped() -> None:
    ddl = _make_ddl(columns=[("id", "STRING"), ("ts", "TIMESTAMP(3)")])
    entry = build_source_table_entry("t", ddl)

    col_map = {c["name"]: c["data_type"] for c in entry["columns"]}
    assert col_map["id"] == "VARCHAR"
    assert col_map["ts"] == "TIMESTAMP(3)"


# ---------------------------------------------------------------------------
# load_sources_yml / source_entry_index / source_table_index
# ---------------------------------------------------------------------------


def test_load_sources_yml_returns_empty_template_when_missing(tmp_path: Path) -> None:
    data = load_sources_yml(tmp_path / "sources.yaml")

    assert data == {"version": 2, "sources": []}


def test_source_entry_index_returns_none_for_absent_source() -> None:
    data = {"sources": [{"name": "other", "tables": []}]}
    assert source_entry_index(data, "kafka") is None


def test_source_entry_index_returns_correct_position() -> None:
    data = {"sources": [{"name": "alpha", "tables": []}, {"name": "kafka", "tables": []}]}
    assert source_entry_index(data, "kafka") == 1


def test_source_table_index_returns_none_for_absent_table() -> None:
    source_entry = {"tables": [{"name": "other"}]}
    assert source_table_index(source_entry, "orders") is None


def test_source_table_index_returns_correct_position() -> None:
    source_entry = {"tables": [{"name": "alpha"}, {"name": "orders"}]}
    assert source_table_index(source_entry, "orders") == 1


# ---------------------------------------------------------------------------
# merge_sources_yml
# ---------------------------------------------------------------------------


def test_merge_sources_yml_creates_new_source() -> None:
    data = {"version": 2, "sources": []}
    ddl = _make_ddl(table_name="raw_orders")
    table_entry = build_source_table_entry("raw_orders", ddl)
    merge_sources_yml(data, "kafka", [table_entry])

    assert data["sources"][0]["name"] == "kafka"
    assert data["sources"][0]["tables"][0]["name"] == "raw_orders"


def test_merge_sources_yml_appends_table_to_existing_source() -> None:
    data = {
        "version": 2,
        "sources": [{"name": "kafka", "tables": [{"name": "existing", "columns": []}]}],
    }
    ddl = _make_ddl(table_name="new_table")
    table_entry = build_source_table_entry("new_table", ddl)
    merge_sources_yml(data, "kafka", [table_entry])

    table_names = [t["name"] for t in data["sources"][0]["tables"]]
    assert "existing" in table_names
    assert "new_table" in table_names


def test_merge_sources_yml_tables_sorted_alphabetically() -> None:
    data = {"version": 2, "sources": []}
    for name in ("zeta", "alpha", "mu"):
        ddl = _make_ddl(table_name=name)
        merge_sources_yml(data, "kafka", [build_source_table_entry(name, ddl)])

    table_names = [t["name"] for t in data["sources"][0]["tables"]]
    assert table_names == sorted(table_names)


def test_merge_sources_yml_sources_sorted_alphabetically() -> None:
    data = {"version": 2, "sources": []}
    for src in ("zeta_src", "alpha_src", "mu_src"):
        ddl = _make_ddl(table_name="t")
        merge_sources_yml(data, src, [build_source_table_entry("t", ddl)])

    source_names = [s["name"] for s in data["sources"]]
    assert source_names == sorted(source_names)


def test_merge_sources_yml_force_replaces_table() -> None:
    data = {
        "version": 2,
        "sources": [
            {
                "name": "kafka",
                "tables": [
                    {
                        "name": "raw_orders",
                        "identifier": "old_id",
                        "columns": [],
                    }
                ],
            }
        ],
    }
    ddl = _make_ddl(table_name="raw_orders")
    new_entry = build_source_table_entry("raw_orders", ddl, identifier="new_id")
    merge_sources_yml(data, "kafka", [new_entry], force=True)

    assert data["sources"][0]["tables"][0]["identifier"] == "new_id"


def test_merge_sources_yml_adds_new_column_without_force() -> None:
    data = {
        "version": 2,
        "sources": [
            {
                "name": "kafka",
                "tables": [
                    {
                        "name": "raw_orders",
                        "identifier": "raw_orders",
                        "columns": [{"name": "order_id", "data_type": "VARCHAR"}],
                    }
                ],
            }
        ],
    }
    ddl = _make_ddl(
        table_name="raw_orders",
        columns=[("order_id", "STRING"), ("amount", "DECIMAL(10, 2)")],
    )
    new_entry = build_source_table_entry("raw_orders", ddl)
    merge_sources_yml(data, "kafka", [new_entry], force=False)

    col_names = [
        c["name"] for c in data["sources"][0]["tables"][0]["columns"]
    ]
    assert "amount" in col_names
    assert "order_id" in col_names


# ---------------------------------------------------------------------------
# emit_sources_yml (integration)
# ---------------------------------------------------------------------------


def test_emit_sources_yml_returns_none_when_no_source_deps(tmp_path: Path) -> None:
    dep = UpstreamDep(
        table_name="ref_model",
        ddl_path=None,
        ddl=None,
        resolution="ref",
        ref_model="ref_model",
    )
    result = emit_sources_yml(tmp_path, "kafka", [dep])

    assert result is None


def test_emit_sources_yml_returns_yaml_for_source_deps(tmp_path: Path) -> None:
    ddl = _make_ddl(table_name="raw_orders")
    dep = UpstreamDep(
        table_name="raw_orders",
        ddl_path=None,
        ddl=ddl,
        resolution="source",
        source_name="kafka",
    )
    result = emit_sources_yml(tmp_path, "kafka", [dep])

    assert result is not None
    data = yaml.safe_load(result)
    assert data["sources"][0]["name"] == "kafka"
    assert data["sources"][0]["tables"][0]["name"] == "raw_orders"


def test_emit_sources_yml_merges_into_existing_file(tmp_path: Path) -> None:
    existing = {
        "version": 2,
        "sources": [{"name": "kafka", "tables": [{"name": "existing", "columns": []}]}],
    }
    (tmp_path / SOURCES_YML_NAME).write_text(yaml.safe_dump(existing), encoding="utf-8")

    ddl = _make_ddl(table_name="raw_orders")
    dep = UpstreamDep(
        table_name="raw_orders",
        ddl_path=None,
        ddl=ddl,
        resolution="source",
        source_name="kafka",
    )
    result = emit_sources_yml(tmp_path, "kafka", [dep])

    assert result is not None
    data = yaml.safe_load(result)
    table_names = [t["name"] for t in data["sources"][0]["tables"]]
    assert "existing" in table_names
    assert "raw_orders" in table_names


def test_emit_sources_yml_skips_deps_without_ddl(tmp_path: Path) -> None:
    dep_with_ddl = UpstreamDep(
        table_name="raw_orders",
        ddl_path=None,
        ddl=_make_ddl(table_name="raw_orders"),
        resolution="source",
        source_name="kafka",
    )
    dep_no_ddl = UpstreamDep(
        table_name="other_table",
        ddl_path=None,
        ddl=None,
        resolution="source",
        source_name="kafka",
    )
    result = emit_sources_yml(tmp_path, "kafka", [dep_with_ddl, dep_no_ddl])

    assert result is not None
    data = yaml.safe_load(result)
    table_names = [t["name"] for t in data["sources"][0]["tables"]]
    assert "raw_orders" in table_names
    assert "other_table" not in table_names


# ---------------------------------------------------------------------------
# dump_* round-trip sanity
# ---------------------------------------------------------------------------


def test_dump_seed_schema_yml_produces_valid_yaml() -> None:
    data = {
        "version": 2,
        "seeds": [{"name": "orders", "config": {"column_types": {"id": "VARCHAR"}}}],
    }
    text = dump_seed_schema_yml(data)

    parsed = yaml.safe_load(text)
    assert parsed["seeds"][0]["name"] == "orders"


def test_dump_sources_yml_produces_valid_yaml() -> None:
    data = {
        "version": 2,
        "sources": [{"name": "kafka", "tables": [{"name": "t", "columns": []}]}],
    }
    text = dump_sources_yml(data)

    parsed = yaml.safe_load(text)
    assert parsed["sources"][0]["name"] == "kafka"
