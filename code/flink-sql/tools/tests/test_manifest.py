"""Tests for deploy manifest generation and loading."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cc_deploy.manifest import (
    classify_sql_file,
    create_manifest_from_folder,
    extract_table_name_from_ddl,
    load_manifest,
    manifest_to_dict,
    statement_name,
)

FLINK_SQL = Path(__file__).resolve().parents[2]
CART_UPDATE = FLINK_SQL / "11-puzzles/cart_update"
ROLLING = FLINK_SQL / "10-windowing/tumble_then_hop_rolling"
JOINS_CC = FLINK_SQL / "04-joins/cc"


def test_classify_sql_file() -> None:
    assert classify_sql_file("ddl.products.sql") == "ddl"
    assert classify_sql_file("dml.insert_products.sql") == "data"
    assert classify_sql_file("insert_customers.sql") == "data"
    assert classify_sql_file("dml.build_cart_line_items.sql") == "pipeline"
    assert classify_sql_file("dml.update_product_price.sql") == "scenario"


def test_statement_name() -> None:
    assert statement_name("cart-update", "ddl", "ddl.products.sql") == "cart-update-ddl-products"
    assert statement_name("cart-update", "pipeline", "dml.build_cart_line_items.sql") == (
        "cart-update-pipeline-build-cart-line-items"
    )


def test_extract_table_name_from_ddl() -> None:
    table = extract_table_name_from_ddl(CART_UPDATE / "ddl.products.sql")
    assert table == "products"


def test_load_existing_manifest() -> None:
    manifest = load_manifest(CART_UPDATE / "deploy_manifest.json")
    assert manifest.user_agent == "flink-studies-cart-update/0.1"
    assert "ddl" in manifest.groups
    assert manifest.drop_tables[0] == "integrated_cart"


def test_create_manifest_from_folder_cart_update_dry_run(tmp_path: Path) -> None:
    for path in CART_UPDATE.glob("*.sql"):
        (tmp_path / path.name).write_text(path.read_text(encoding="utf-8"), encoding="utf-8")

    manifest = create_manifest_from_folder(tmp_path, prefix="cart-update", write=False, overwrite=True)

    assert manifest.deploy_all == ["ddl", "pipeline", "data"]
    assert manifest.undeploy_all == ["scenario", "data", "pipeline"]
    assert manifest.groups["ddl"][0][1].startswith("ddl.")
    assert manifest.groups["scenario"]
    assert "products" in manifest.drop_tables
    assert manifest.drop_statement_prefix == "cart-update-drop"


def test_create_manifest_from_folder_matches_existing_groups(tmp_path: Path) -> None:
    for path in ROLLING.glob("*.sql"):
        (tmp_path / path.name).write_text(path.read_text(encoding="utf-8"), encoding="utf-8")

    generated = create_manifest_from_folder(tmp_path, prefix="tumble-hop", write=False, overwrite=True)
    existing = load_manifest(ROLLING / "deploy_manifest.json")

    assert generated.deploy_all == existing.deploy_all
    assert set(generated.groups) == set(existing.groups)
    assert generated.drop_tables == existing.drop_tables


def test_create_manifest_from_folder_refuses_overwrite(tmp_path: Path) -> None:
    (tmp_path / "deploy_manifest.json").write_text("{}", encoding="utf-8")
    with pytest.raises(FileExistsError):
        create_manifest_from_folder(tmp_path, write=False)


def test_create_manifest_writes_file(tmp_path: Path) -> None:
    (tmp_path / "ddl.events.sql").write_text(
        "CREATE TABLE IF NOT EXISTS events (id STRING) DISTRIBUTED BY HASH(id) INTO 1 BUCKETS;",
        encoding="utf-8",
    )
    (tmp_path / "dml.events.sql").write_text(
        "INSERT INTO events SELECT id FROM source;",
        encoding="utf-8",
    )

    manifest = create_manifest_from_folder(tmp_path, prefix="demo", write=True, overwrite=True)
    manifest_path = tmp_path / "deploy_manifest.json"

    assert manifest_path.is_file()
    roundtrip = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert roundtrip == manifest_to_dict(manifest)


def test_custom_group_op_ddl() -> None:
    manifest = load_manifest(JOINS_CC / "deploy_manifest.json")
    statements = manifest.statements_for("op_ddl")
    assert len(statements) == 2
    assert statements[0][1] == "ddl.orders_nowm.sql"
    assert "op_ddl" in manifest.groups
    assert "op_ddl" not in manifest.deploy_all


def test_groups_cli(capsys, monkeypatch) -> None:
    import sys

    from cc_deploy.deploy_flink_statements import main

    monkeypatch.setattr(
        sys,
        "argv",
        ["deploy_flink_statements", "--sql-dir", str(JOINS_CC), "groups"],
    )
    main()
    out = capsys.readouterr().out
    assert "op_ddl: 2 statement(s)" in out
    assert "ddl:" in out
    assert "deploy_all" in out
