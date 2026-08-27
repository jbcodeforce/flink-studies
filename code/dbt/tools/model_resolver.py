"""Resolve dbt model column definitions from YAML files and SQL.

Given a dbt project root (the directory containing ``dbt_project.yml``),
:class:`ModelResolver` locates model YAML files and returns their column
definitions as :class:`ColumnSpec` objects.

When a model's YAML has no columns (or the model has no YAML at all), the
resolver falls back to parsing the model's SQL file and recursively resolving
the upstream models it references — this correctly handles ``SELECT *`` chains.

Usage::

    from model_resolver import ModelResolver

    resolver = ModelResolver(project_root=Path("airbnb_streaming"))
    columns = resolver.get_columns("dim_hosts_cleansed")
    # → [ColumnSpec("host_id", "string"), ColumnSpec("host_name", "string"), …]
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import yaml

if TYPE_CHECKING:
    pass


# ── ColumnSpec (local; mirrors schema_registry.ColumnSpec) ───────────────────

@dataclass
class ColumnSpec:
    """One column entry — name and dbt/Flink data type."""
    name: str
    data_type: str


# ── ModelResolver ─────────────────────────────────────────────────────────────

class ModelResolver:
    """Locate and load column definitions for dbt models.

    Args:
        project_root: Path to the directory that contains ``dbt_project.yml``.
                      All model YAML / SQL files are located relative to this.
    """

    def __init__(self, project_root: Path) -> None:
        self._root = project_root.resolve()
        self._model_paths = self._read_model_paths()
        # Cache to avoid re-parsing the same model multiple times.
        self._cache: dict[str, list[ColumnSpec]] = {}

    # ── public API ────────────────────────────────────────────────────────────

    def get_columns(self, model_name: str, _stack: frozenset[str] | None = None) -> list[ColumnSpec]:
        """Return the column list for *model_name*.

        Resolution order:
        1. Cache hit.
        2. Columns declared in a model YAML file.
        3. Columns declared in a sources YAML file (raw source tables).
        4. Columns inferred by parsing the model's SQL file.

        *_stack* tracks in-progress resolutions to break cycles.
        """
        if model_name in self._cache:
            return self._cache[model_name]

        stack = _stack or frozenset()
        if model_name in stack:
            # Cycle detected — return empty rather than infinite loop.
            return []

        stack = stack | {model_name}

        # 1. Try model YAML.
        columns = self._from_yaml(model_name)
        if columns:
            self._cache[model_name] = columns
            return columns

        # 2. Try sources YAML (for raw_* source tables).
        columns = self.get_source_columns(model_name)
        if columns:
            self._cache[model_name] = columns
            return columns

        # 3. Fall back to SQL parsing.
        columns = self._from_sql(model_name, stack)
        self._cache[model_name] = columns
        return columns

    def find_model_yaml(self, model_name: str) -> Path | None:
        """Return the first YAML file declaring a model named *model_name*, or None."""
        for model_path in self._model_paths:
            search_dir = self._root / model_path
            if not search_dir.is_dir():
                continue
            for yml_file in search_dir.rglob("*.yml"):
                if self._yaml_declares_model(yml_file, model_name):
                    return yml_file
            for yml_file in search_dir.rglob("*.yaml"):
                if self._yaml_declares_model(yml_file, model_name):
                    return yml_file
        return None

    def get_source_columns(self, table_name: str) -> list[ColumnSpec]:
        """Return columns for a raw source table defined in any ``sources.yaml``.

        Looks for ``sources:`` YAML files (commonly ``models/sources.yaml``) and
        returns the columns for the first table entry whose name matches
        *table_name*.
        """
        for model_path in self._model_paths:
            search_dir = self._root / model_path
            if not search_dir.is_dir():
                continue
            for yml_file in list(search_dir.rglob("sources.yaml")) + list(search_dir.rglob("sources.yml")):
                cols = self._source_columns_from_yaml(yml_file, table_name)
                if cols:
                    return cols
        return []

    @staticmethod
    def _source_columns_from_yaml(yml_path: Path, table_name: str) -> list[ColumnSpec]:
        """Extract columns for *table_name* from a ``sources:`` YAML file."""
        try:
            with yml_path.open() as fh:
                data = yaml.safe_load(fh) or {}
        except Exception:
            return []
        for source in data.get("sources", []):
            for table in source.get("tables", []):
                if table.get("name") == table_name:
                    raw_cols = table.get("columns", [])
                    if raw_cols:
                        return [
                            ColumnSpec(name=col["name"], data_type=col.get("data_type", "string"))
                            for col in raw_cols
                            if "name" in col
                        ]
        return []

    def find_model_sql(self, model_name: str) -> Path | None:
        """Return the first `.sql` file whose stem matches *model_name*, or None."""
        for model_path in self._model_paths:
            search_dir = self._root / model_path
            if not search_dir.is_dir():
                continue
            for sql_file in search_dir.rglob(f"{model_name}.sql"):
                return sql_file
        return None

    # ── internals ─────────────────────────────────────────────────────────────

    def _read_model_paths(self) -> list[str]:
        """Read ``model-paths`` from ``dbt_project.yml`` (default: ``["models"]``)."""
        proj_file = self._root / "dbt_project.yml"
        if not proj_file.is_file():
            return ["models"]
        with proj_file.open() as fh:
            data = yaml.safe_load(fh) or {}
        return data.get("model-paths", ["models"])

    def _from_yaml(self, model_name: str) -> list[ColumnSpec]:
        """Load columns from a model YAML file, or return [] if not found / empty."""
        yml_path = self.find_model_yaml(model_name)
        if yml_path is None:
            return []
        with yml_path.open() as fh:
            data = yaml.safe_load(fh) or {}

        for model in data.get("models", []):
            if model.get("name") == model_name:
                raw_cols = model.get("columns", [])
                if not raw_cols:
                    return []
                return [
                    ColumnSpec(name=col["name"], data_type=col.get("data_type", "string"))
                    for col in raw_cols
                    if "name" in col
                ]
        return []

    def _from_sql(self, model_name: str, stack: frozenset[str]) -> list[ColumnSpec]:
        """Infer columns by parsing the model's SQL file."""
        # Import lazily to avoid circular imports; sql_parser / type_inferrer
        # are co-located with this module.
        _here = Path(__file__).parent
        if str(_here) not in sys.path:
            sys.path.insert(0, str(_here))

        from sql_parser import parse_select, extract_refs, strip_jinja_config  # noqa: PLC0415
        from type_inferrer import build_catalog, infer_type  # noqa: PLC0415

        sql_path = self.find_model_sql(model_name)
        if sql_path is None:
            return []

        sql = sql_path.read_text()

        # Build catalog: CTE alias → {col_name: data_type}
        # We need the refs declared in each CTE to map aliases to models.
        cte_alias_to_model = _extract_cte_alias_map(sql)
        catalog: dict[str, dict[str, str]] = {}
        for alias, ref_model in cte_alias_to_model.items():
            upstream_cols = self.get_columns(ref_model, stack)
            catalog[alias] = {c.name: c.data_type for c in upstream_cols}
            # Also register the model name itself as a direct table ref
            # (for queries that use the model name rather than an alias).
            catalog[ref_model] = catalog[alias]

        items = parse_select(sql)
        result: list[ColumnSpec] = []
        for item in items:
            if item.output_name == "*":
                # Expand SELECT * from the single upstream source.
                source_cols = _expand_star(catalog)
                result.extend(source_cols)
            else:
                dtype = infer_type(item, catalog)
                result.append(ColumnSpec(name=item.output_name, data_type=dtype))
        return result

    @staticmethod
    def _yaml_declares_model(yml_path: Path, model_name: str) -> bool:
        """Return True if *yml_path* contains a models entry named *model_name*."""
        try:
            with yml_path.open() as fh:
                data = yaml.safe_load(fh) or {}
        except Exception:
            return False
        for model in data.get("models", []):
            if isinstance(model, dict) and model.get("name") == model_name:
                return True
        return False


# ── CTE alias extraction (standalone helper) ─────────────────────────────────

def _extract_cte_alias_map(sql: str) -> dict[str, str]:
    """Return a mapping of CTE alias → model name for all CTEs in *sql*.

    Only covers the common dbt pattern::

        WITH alias AS (SELECT ... FROM {{ ref('model') }})

    For each CTE, we extract:
    - the CTE alias (left of AS)
    - the single ``ref('model')`` name inside the CTE body (if present)

    CTEs whose body contains a sub-SELECT with multiple refs (e.g. joins inside
    a CTE) are skipped; they will be handled at the outer SELECT level.
    """
    import re  # noqa: PLC0415

    _REF_RE_LOCAL = re.compile(
        r"""\{\{-?\s*ref\s*\(\s*['"]([^'"]+)['"]\s*\)\s*-?\}\}""",
        re.IGNORECASE,
    )
    _SOURCE_RE_LOCAL = re.compile(
        r"""\{\{-?\s*source\s*\(\s*['"][^'"]+['"]\s*,\s*['"]([^'"]+)['"]\s*\)\s*-?\}\}""",
        re.IGNORECASE,
    )

    import sqlglot  # noqa: PLC0415
    import sqlglot.expressions as exp  # noqa: PLC0415

    # Replace refs and source() with bare identifiers so sqlglot can parse CTEs.
    cleaned = _REF_RE_LOCAL.sub(lambda m: m.group(1), sql)
    cleaned = _SOURCE_RE_LOCAL.sub(lambda m: m.group(1), cleaned)

    # Strip Jinja config block.
    import re as re2  # noqa: PLC0415
    cleaned = re2.sub(
        r"\{\{-?\s*config\s*\(.*?\)\s*-?\}\}", "", cleaned, flags=re2.DOTALL | re2.IGNORECASE
    ).strip()

    try:
        statement = sqlglot.parse_one(cleaned)
    except Exception:
        return {}

    alias_map: dict[str, str] = {}

    # Walk CTE definitions.
    for cte in statement.find_all(exp.CTE):
        alias = cte.alias
        if not alias:
            continue
        # Find all table references inside this CTE's body.
        tables = list(cte.find_all(exp.Table))
        if len(tables) == 1:
            alias_map[alias] = tables[0].name
        # If there are multiple table refs inside a single CTE (rare), skip —
        # the JOIN case is handled at the outer SELECT level via table aliases.

    # Also capture direct table references in the main FROM/JOIN clauses
    # (for queries that don't use CTEs, or for JOIN partners in the outer query).
    # We look for aliased table references like: dim_listings_cleansed AS l.
    for table in statement.find_all(exp.Table):
        tbl_name = table.name
        tbl_alias = table.alias
        if tbl_alias and tbl_name:
            alias_map[tbl_alias] = tbl_name
        elif tbl_name and not tbl_alias:
            # Register name → name (no alias case).
            alias_map.setdefault(tbl_name, tbl_name)

    return alias_map


def _expand_star(catalog: dict[str, dict[str, str]]) -> list[ColumnSpec]:
    """Expand SELECT * by returning all columns from all catalog entries.

    When a single upstream source is present, returns its columns in order.
    For multiple sources, merges them (first-seen wins for duplicate names).
    """
    seen: dict[str, str] = {}
    for cols in catalog.values():
        for name, dtype in cols.items():
            seen.setdefault(name, dtype)
    return [ColumnSpec(name=n, data_type=t) for n, t in seen.items()]
