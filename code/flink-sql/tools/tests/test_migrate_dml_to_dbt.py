"""Tests for Flink DML → dbt migration."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest
from typer.testing import CliRunner

from flink_dbt_migrate.emit_model import emit_model_sql
from flink_dbt_migrate.migrate_dml_to_dbt import app
from flink_dbt_migrate.migrate import migrate_dml_to_dbt
from flink_dbt_migrate.parse_ddl import parse_ddl
from flink_dbt_migrate.parse_dml import discover_ddl_path, parse_dml
from flink_dbt_migrate.rewrite_refs import collect_cte_names, rewrite_refs
from flink_dbt_migrate.type_map import flink_type_to_dbt
from flink_dbt_migrate.validate_compile import DbtCompileError, DbtCompileResult

FLINK_SQL = Path(__file__).resolve().parents[2]
CART_UPDATE = FLINK_SQL / "11-puzzles/cart_update"
ROLLING = FLINK_SQL / "10-windowing/tumble_then_hop_rolling"
JOINS_CC_FLINK = FLINK_SQL / "04-joins/cc-flink"
JOINS_CC_DBT = FLINK_SQL / "04-joins/cc_dbt"
JOIN_04 = FLINK_SQL / "04-joins"


@pytest.fixture
def cli_runner() -> CliRunner:
    return CliRunner()


def test_cli_dry_run(cli_runner: CliRunner, tmp_path: Path) -> None:
    result = cli_runner.invoke(
        app,
        [str(ROLLING / "dml.rolling_features.sql"), str(tmp_path)],
    )

    assert result.exit_code == 0
    assert "# --- model ---" in result.stdout
    assert "materialized='streaming_table'" in result.stdout
    assert "# --- schema.yml ---" in result.stdout
    assert "name: rolling_features" in result.stdout


def test_cli_write(cli_runner: CliRunner, tmp_path: Path) -> None:
    result = cli_runner.invoke(
        app,
        [str(ROLLING / "dml.rolling_features.sql"), str(tmp_path), "--write"],
    )

    assert result.exit_code == 0
    assert (tmp_path / "rolling_features.sql").exists()
    assert (tmp_path / "schema.yml").exists()
    assert "Wrote" in result.stdout


def test_cli_missing_statement_file(cli_runner: CliRunner, tmp_path: Path) -> None:
    result = cli_runner.invoke(
        app,
        [str(tmp_path / "missing.sql"), str(tmp_path)],
    )

    assert result.exit_code == 1
    assert "Statement file not found" in result.stderr


def test_cli_check_exits_when_output_would_change(
    cli_runner: CliRunner, tmp_path: Path
) -> None:
    result = cli_runner.invoke(
        app,
        [str(ROLLING / "dml.rolling_features.sql"), str(tmp_path), "--check"],
    )

    assert result.exit_code == 1
    assert "Output differs" in result.stderr


def test_cli_check_passes_when_files_match(
    cli_runner: CliRunner, tmp_path: Path
) -> None:
    write = cli_runner.invoke(
        app,
        [str(ROLLING / "dml.rolling_features.sql"), str(tmp_path), "--write"],
    )
    assert write.exit_code == 0

    check = cli_runner.invoke(
        app,
        [str(ROLLING / "dml.rolling_features.sql"), str(tmp_path), "--check"],
    )
    assert check.exit_code == 0


def test_cli_ref_table_override(cli_runner: CliRunner, tmp_path: Path) -> None:
    result = cli_runner.invoke(
        app,
        [
            str(ROLLING / "dml.rolling_features.sql"),
            str(tmp_path),
            "--ref-table",
            "events=src_events",
        ],
    )

    assert result.exit_code == 0
    assert "{{ ref('src_events') }}" in result.stdout


def test_cli_write_refuses_overwrite_without_force(
    cli_runner: CliRunner, tmp_path: Path
) -> None:
    dml = str(ROLLING / "dml.rolling_features.sql")
    first = cli_runner.invoke(app, [dml, str(tmp_path), "--write"])
    assert first.exit_code == 0

    second = cli_runner.invoke(app, [dml, str(tmp_path), "--write"])
    assert second.exit_code == 1
    assert "already exists" in second.stderr


def test_cli_write_force_overwrites(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(ROLLING / "dml.rolling_features.sql")
    cli_runner.invoke(app, [dml, str(tmp_path), "--write"])

    result = cli_runner.invoke(app, [dml, str(tmp_path), "--write", "--force"])
    assert result.exit_code == 0
    assert "Wrote" in result.stdout


def _rolling_compiled_sql() -> str:
    source_dml = parse_dml((ROLLING / "dml.rolling_features.sql").read_text(encoding="utf-8"))
    return source_dml.body


def _mock_validate_success(
    tmp_path: Path,
    model_name: str = "rolling_features",
) -> DbtCompileResult:
    project_dir = tmp_path / "dbt_project"
    models_dir = project_dir / "models"
    models_dir.mkdir(parents=True)
    (project_dir / "dbt_project.yml").write_text("name: demo\n", encoding="utf-8")
    model_path = models_dir / f"{model_name}.sql"
    compiled_dir = project_dir / "target" / "compiled" / "demo"
    compiled_dir.mkdir(parents=True)
    compiled_path = compiled_dir / f"{model_name}.sql"
    compiled_path.write_text(_rolling_compiled_sql(), encoding="utf-8")
    return DbtCompileResult(
        project_dir=project_dir,
        model_name=model_name,
        compiled_path=compiled_path,
        compiled_sql=_rolling_compiled_sql(),
        stdout="",
        stderr="",
    )


def test_cli_validate_success(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(ROLLING / "dml.rolling_features.sql")
    mock_result = _mock_validate_success(tmp_path)

    with patch(
        "flink_dbt_migrate.migrate_dml_to_dbt.validate_compiled_migration",
        return_value=mock_result,
    ):
        result = cli_runner.invoke(
            app,
            [dml, str(tmp_path), "--validate", "--dbt-project-dir", str(mock_result.project_dir)],
        )

    assert result.exit_code == 0
    assert "Validation passed" in result.stdout
    assert "Reconstructed INSERT INTO rolling_features" in result.stdout
    assert not (tmp_path / "rolling_features.sql").exists()


def test_cli_validate_body_mismatch(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(ROLLING / "dml.rolling_features.sql")
    mock_result = _mock_validate_success(tmp_path)
    mock_result = DbtCompileResult(
        project_dir=mock_result.project_dir,
        model_name=mock_result.model_name,
        compiled_path=mock_result.compiled_path,
        compiled_sql="SELECT 1",
        stdout=mock_result.stdout,
        stderr=mock_result.stderr,
    )
    mock_result.compiled_path.write_text("SELECT 1", encoding="utf-8")

    with patch(
        "flink_dbt_migrate.migrate_dml_to_dbt.validate_compiled_migration",
        return_value=mock_result,
    ):
        result = cli_runner.invoke(
            app,
            [dml, str(tmp_path), "--validate", "--dbt-project-dir", str(mock_result.project_dir)],
        )

    assert result.exit_code == 1
    assert "# Query body mismatch" in result.stdout


def test_cli_validate_compile_failure(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(ROLLING / "dml.rolling_features.sql")
    project_dir = tmp_path / "dbt_project"
    project_dir.mkdir()
    (project_dir / "dbt_project.yml").write_text("name: demo\n", encoding="utf-8")

    with patch(
        "flink_dbt_migrate.migrate_dml_to_dbt.validate_compiled_migration",
        side_effect=DbtCompileError("Compilation Error: missing ref"),
    ):
        result = cli_runner.invoke(
            app,
            [dml, str(tmp_path), "--validate", "--dbt-project-dir", str(project_dir)],
        )

    assert result.exit_code == 1
    assert "missing ref" in result.stderr


def test_migrate_enriched_orders_uses_sources(tmp_path: Path) -> None:
    target = JOINS_CC_DBT / "models/intermediates/enriched_orders"
    result = migrate_dml_to_dbt(
        JOINS_CC_FLINK / "dml.enriched_orders.sql",
        target,
        ddl_file=JOINS_CC_FLINK / "ddl.enriched_orders.sql",
        source_name="cc_flink",
    )

    assert "{{ source('cc_flink', 'd04_orders') }}" in result.model_sql
    assert "{{ source('cc_flink', 'd04_products') }}" in result.model_sql
    assert "{{ ref('d04_orders') }}" not in result.model_sql
    assert result.sources_yml is not None
    assert "name: cc_flink" in result.sources_yml
    assert "name: d04_orders" in result.sources_yml
    assert "name: d04_products" in result.sources_yml


def test_cli_no_sources_preserves_ref(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(JOINS_CC_FLINK / "dml.enriched_orders.sql")
    ddl = str(JOINS_CC_FLINK / "ddl.enriched_orders.sql")
    result = cli_runner.invoke(
        app,
        [dml, str(tmp_path), "--ddl-file", ddl, "--no-sources"],
    )

    assert result.exit_code == 0
    assert "{{ ref('d04_orders') }}" in result.stdout
    assert "# --- sources.yaml ---" not in result.stdout


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
    assert "FROM {{ source('tumble_then_hop_rolling', 'events') }}" in result.model_sql
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
    assert "FROM {{ source('cart_update', 'cart_events') }}" in result.model_sql
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


def test_cli_migrate_enriched_orders_write(cli_runner: CliRunner, tmp_path: Path) -> None:
    dml = str(JOINS_CC_FLINK / "dml.enriched_orders.sql")
    ddl = str(JOINS_CC_FLINK / "ddl.enriched_orders.sql")
    target = tmp_path / "models" / "intermediates" / "enriched_orders"
    project = tmp_path
    (project / "dbt_project.yml").write_text("name: cc_dbt\n", encoding="utf-8")

    result = cli_runner.invoke(
        app,
        [dml, str(target), "--ddl-file", ddl, "--write", "--source-name", "cc_flink"],
    )
    assert result.exit_code == 0
    assert (project / "models" / "sources.yaml").exists()
    assert "{{ source('cc_flink', 'd04_orders') }}" in (
        target / "d04_enriched_orders.sql"
    ).read_text(encoding="utf-8")