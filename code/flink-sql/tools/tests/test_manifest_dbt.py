"""
Tests for the dbt-confluent manifest generation helpers and
create_manifest_from_dbt_folder().

These tests use:
- Unit tests for pure helpers (no I/O)
- tmp_path fixtures for filesystem helpers
- An integration test against the real airbnb_streaming dbt project
  (skipped when dbt-confluent is not installed)
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

# Skip the whole module if dbt-confluent is not installed (e.g. CI without --extra dbt)
dbt_confluent = pytest.importorskip(
    "dbt.adapters.confluent.naming",
    reason="dbt-confluent not installed (uv sync --extra dbt)",
)

from dbt.adapters.confluent.naming import sanitize_statement_name

from manifest.manifest import (
    _dbt_group_for_node,
    _find_dbt_project_root,
    _read_dbt_manifest_nodes,
    _read_dbt_project_name,
    _read_dbt_source_tables,
    _read_statement_name_prefix,
    create_manifest_from_dbt_folder,
)

# ---------------------------------------------------------------------------
# Helpers — path to the real airbnb_streaming project in this repo
# ---------------------------------------------------------------------------

_REPO_ROOT = Path(__file__).parent.parent.parent.parent.parent  # flink-studies/
_AIRBNB = _REPO_ROOT / "code" / "dbt" / "airbnb_streaming"


# ---------------------------------------------------------------------------
# sanitize_statement_name (imported from dbt-confluent) — algorithm tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "raw, expected_prefix",
    [
        # underscores → replaced → hash appended
        ("dbt-airbnb_streaming-src_hosts", "dbt-airbnb-streaming-src-hosts-"),
        ("fw_crm_customers_pk", "fw-crm-customers-pk-"),
        # already clean → no hash
        ("dbt-airbnb-streaming-src-hosts", "dbt-airbnb-streaming-src-hosts"),
    ],
)
def test_sanitize_statement_name_prefix(raw: str, expected_prefix: str) -> None:
    result = sanitize_statement_name(raw)
    assert result.startswith(expected_prefix), (
        f"sanitize({raw!r}) = {result!r}, expected prefix {expected_prefix!r}"
    )


def test_sanitize_statement_name_hash_length() -> None:
    """When a hash is appended it is exactly 6 hex chars."""
    result = sanitize_statement_name("has_underscore")
    # format: <base>-<6hexchars>
    parts = result.rsplit("-", 1)
    assert len(parts) == 2
    assert len(parts[1]) == 6
    assert all(c in "0123456789abcdef" for c in parts[1])


def test_sanitize_statement_name_no_hash_for_clean_name() -> None:
    result = sanitize_statement_name("fw-crm-customers-pk")
    assert result == "fw-crm-customers-pk"


def test_sanitize_statement_name_long_name_gets_hash() -> None:
    long_name = "a" * 101  # > 100 chars
    result = sanitize_statement_name(long_name)
    assert len(result) <= 100


# ---------------------------------------------------------------------------
# _dbt_group_for_node
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "path, resource_type, expected_group",
    [
        ("user_reviews/sources/src_hosts.sql", "model", "sources"),
        ("user_reviews/dimensions/dim_hosts_cleansed.sql", "model", "dimensions"),
        ("user_reviews/facts/fct_reviews.sql", "model", "facts"),
        ("crm/marts/joins/txn_customer_equi.sql", "model", "marts"),
        ("seed_full_moon_dates.csv", "seed", "seeds"),
        ("some/other/pipeline.sql", "model", "pipeline"),
    ],
)
def test_dbt_group_for_node(path: str, resource_type: str, expected_group: str) -> None:
    assert _dbt_group_for_node(path, resource_type) == expected_group


# ---------------------------------------------------------------------------
# _find_dbt_project_root
# ---------------------------------------------------------------------------


def test_find_dbt_project_root_from_project_root(tmp_path: Path) -> None:
    (tmp_path / "dbt_project.yml").write_text("name: test_proj\nprofile: cc_flink\n")
    assert _find_dbt_project_root(tmp_path) == tmp_path


def test_find_dbt_project_root_from_models_subdir(tmp_path: Path) -> None:
    (tmp_path / "dbt_project.yml").write_text("name: test_proj\nprofile: cc_flink\n")
    models = tmp_path / "models" / "sources"
    models.mkdir(parents=True)
    assert _find_dbt_project_root(models) == tmp_path


def test_find_dbt_project_root_via_sl_dbt_yaml(tmp_path: Path) -> None:
    (tmp_path / "sl_dbt.yaml").write_text("project_type: data-product\n")
    (tmp_path / "dbt_project.yml").write_text("name: test_proj\nprofile: cc_flink\n")
    subdir = tmp_path / "models"
    subdir.mkdir()
    assert _find_dbt_project_root(subdir) == tmp_path


def test_find_dbt_project_root_not_found(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="dbt project root"):
        _find_dbt_project_root(tmp_path / "no_dbt_here")


# ---------------------------------------------------------------------------
# _read_statement_name_prefix
# ---------------------------------------------------------------------------


def test_read_statement_name_prefix_fallback_on_missing_file() -> None:
    # Profile that certainly doesn't exist
    assert _read_statement_name_prefix("__no_such_profile__") == "dbt-"


def test_read_statement_name_prefix_from_fixture(tmp_path: Path, monkeypatch) -> None:
    profiles = tmp_path / ".dbt" / "profiles.yml"
    profiles.parent.mkdir(parents=True)
    profiles.write_text(
        "cc_flink:\n"
        "  outputs:\n"
        "    dev:\n"
        "      type: confluent\n"
        "      statement_name_prefix: 'myco-'\n"
    )
    monkeypatch.setattr(Path, "home", staticmethod(lambda: tmp_path))
    assert _read_statement_name_prefix("cc_flink") == "myco-"


# ---------------------------------------------------------------------------
# _read_dbt_manifest_nodes — minimal fixture
# ---------------------------------------------------------------------------


def _make_dbt_manifest(tmp_path: Path, nodes: dict) -> Path:
    target = tmp_path / "target"
    target.mkdir()
    (target / "manifest.json").write_text(
        json.dumps({"metadata": {}, "nodes": nodes}), encoding="utf-8"
    )
    return tmp_path


def test_read_dbt_manifest_nodes_basic(tmp_path: Path) -> None:
    _make_dbt_manifest(
        tmp_path,
        {
            "model.proj.src_hosts": {
                "name": "src_hosts",
                "path": "sources/src_hosts.sql",
                "resource_type": "model",
                "config": {"statement_name": None},
            },
            "seed.proj.seed_full_moon": {
                "name": "seed_full_moon",
                "path": "seed_full_moon.csv",
                "resource_type": "seed",
                "config": {},
            },
            "test.proj.some_test": {
                "name": "some_test",
                "path": "tests/test.sql",
                "resource_type": "test",
                "config": {},
            },
        },
    )
    nodes = _read_dbt_manifest_nodes(tmp_path)
    names = {n["name"] for n in nodes}
    assert names == {"src_hosts", "seed_full_moon"}
    # test nodes are excluded
    assert "some_test" not in names


def test_read_dbt_manifest_nodes_explicit_statement_name(tmp_path: Path) -> None:
    _make_dbt_manifest(
        tmp_path,
        {
            "model.proj.customers_pk": {
                "name": "customers_pk",
                "path": "dimensions/customers_pk.sql",
                "resource_type": "model",
                "config": {"statement_name": "fw_crm_customers_pk"},
            },
        },
    )
    nodes = _read_dbt_manifest_nodes(tmp_path)
    assert nodes[0]["statement_name_override"] == "fw_crm_customers_pk"


def test_read_dbt_manifest_nodes_missing_file(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="dbt manifest not found"):
        _read_dbt_manifest_nodes(tmp_path)


# ---------------------------------------------------------------------------
# _read_dbt_source_tables — minimal fixture
# ---------------------------------------------------------------------------


def test_read_dbt_source_tables(tmp_path: Path) -> None:
    models = tmp_path / "models"
    models.mkdir()
    (models / "sources.yaml").write_text(
        "sources:\n"
        "  - name: raw_hosts\n"
        "    tables:\n"
        "      - name: raw_hosts\n"
        "  - name: raw_listings\n"
        "    tables:\n"
        "      - name: raw_listings\n"
    )
    result = _read_dbt_source_tables(tmp_path)
    assert result == ["raw_hosts", "raw_listings"]


def test_read_dbt_source_tables_deduplicates(tmp_path: Path) -> None:
    models = tmp_path / "models"
    models.mkdir()
    sub = models / "sub"
    sub.mkdir()
    for yaml_path in [models / "sources.yaml", sub / "sources.yaml"]:
        yaml_path.write_text(
            "sources:\n  - name: raw\n    tables:\n      - name: raw_hosts\n"
        )
    result = _read_dbt_source_tables(tmp_path)
    assert result.count("raw_hosts") == 1


# ---------------------------------------------------------------------------
# create_manifest_from_dbt_folder — integration test (real airbnb_streaming)
# ---------------------------------------------------------------------------

_AIRBNB_MISSING = not _AIRBNB.exists()


@pytest.mark.skipif(_AIRBNB_MISSING, reason="airbnb_streaming project not present")
def test_create_manifest_from_dbt_folder_airbnb() -> None:
    manifest = create_manifest_from_dbt_folder(_AIRBNB)

    # Groups present
    assert "sources" in manifest.groups
    assert "dimensions" in manifest.groups
    assert "facts" in manifest.groups
    assert "seeds" in manifest.groups

    # deploy/undeploy ordering invariants
    assert manifest.deploy_all.index("sources") < manifest.deploy_all.index("facts")
    assert manifest.undeploy_all.index("facts") < manifest.undeploy_all.index("sources")

    # All statement names are sanitized (no underscores)
    for group in manifest.groups.values():
        for ref in group:
            assert "_" not in ref.name, f"Underscore in statement name: {ref.name!r}"
            assert ref.file == "_noop"

    # drop_tables has raw sources appended at the end
    raw_sources = _read_dbt_source_tables(_AIRBNB)
    for src in raw_sources:
        assert src in manifest.drop_tables
    # raw sources come after model tables
    if raw_sources:
        last_model_idx = max(
            manifest.drop_tables.index(n)
            for n in manifest.drop_tables
            if n not in raw_sources
        )
        first_raw_idx = manifest.drop_tables.index(raw_sources[0])
        assert first_raw_idx > last_model_idx

    # drop_statement_prefix is set and sanitized
    assert manifest.drop_statement_prefix
    assert "_" not in manifest.drop_statement_prefix


@pytest.mark.skipif(_AIRBNB_MISSING, reason="airbnb_streaming project not present")
def test_create_manifest_from_dbt_folder_specific_statements() -> None:
    """src_hosts statement name must follow dbt-confluent naming convention."""
    manifest = create_manifest_from_dbt_folder(_AIRBNB)
    src_host_names = [r.name for r in manifest.groups.get("sources", [])]
    # Each name must start with the sanitized prefix+project pattern
    for name in src_host_names:
        assert name.startswith("dbt-"), f"Unexpected prefix in {name!r}"
        assert "airbnb" in name, f"Project name missing from {name!r}"
