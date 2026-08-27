"""Infer dbt/Flink data types for SQL SELECT expressions.

Given a :class:`~sql_parser.SelectItem` and a column catalog mapping
table-alias → {column_name → data_type}, :func:`infer_type` returns the
appropriate type string for that output column.

Handled patterns
----------------
- **Plain column reference** — ``l.listing_id``, ``host_id``: look up in catalog.
- **CAST** — ``CAST(expr AS DECIMAL(10,2))``: extract the target type.
- **GREATEST / LEAST** — inherit type of the first resolvable argument.
- **COALESCE / IFNULL / NVL** — inherit type of the first non-literal argument.
- **Anything else** — fall back to ``"string"``.

Catalog shape::

    {
        "l": {"listing_id": "string", "price": "decimal(10,2)", ...},
        "h": {"host_id": "string", "is_superhost": "boolean", ...},
    }
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import sqlglot.expressions as exp

if TYPE_CHECKING:
    from sql_parser import SelectItem


# ── Catalog builder ───────────────────────────────────────────────────────────

def build_catalog(
    cte_alias_to_columns: dict[str, list[Any]],
) -> dict[str, dict[str, str]]:
    """Build a ``{alias: {col: type}}`` catalog from resolved upstream columns.

    Args:
        cte_alias_to_columns: maps CTE/table alias to a list of objects that
                              have ``.name`` and ``.data_type`` attributes
                              (e.g. :class:`~model_resolver.ColumnSpec`).

    Returns:
        Nested dict suitable for passing to :func:`infer_type`.
    """
    return {
        alias: {col.name: col.data_type for col in cols}
        for alias, cols in cte_alias_to_columns.items()
    }


# ── Main entry point ──────────────────────────────────────────────────────────

def infer_type(item: "SelectItem", catalog: dict[str, dict[str, str]]) -> str:
    """Return the dbt/Flink data type for *item* given *catalog*.

    Falls back to ``"string"`` when the type cannot be determined.
    """
    return _type_of(item.expression, item.table_alias, catalog)


# ── Expression type resolution ────────────────────────────────────────────────

def _type_of(
    node: exp.Expression,
    default_table: str | None,
    catalog: dict[str, dict[str, str]],
) -> str:
    """Recursively resolve the type of *node*."""

    # ── Plain column reference ────────────────────────────────────────────────
    if isinstance(node, exp.Column):
        tbl = node.table or default_table
        col = node.name
        if tbl and tbl in catalog:
            dtype = catalog[tbl].get(col)
            if dtype:
                return dtype
        # Try all catalog entries when no table qualifier is present.
        if not tbl:
            for cols in catalog.values():
                if col in cols:
                    return cols[col]
        return "string"

    # ── CAST ──────────────────────────────────────────────────────────────────
    if isinstance(node, exp.Cast):
        return _cast_type_str(node.to)

    # ── TryCast (some dialects emit this for CAST) ────────────────────────────
    if isinstance(node, exp.TryCast):
        return _cast_type_str(node.to)

    # ── CASE / IIF ────────────────────────────────────────────────────────────
    if isinstance(node, exp.Case):
        # Check THEN and ELSE branches — return the first non-string type found.
        for when in node.args.get("ifs", []):
            t = _type_of(when.args.get("true", when), default_table, catalog)
            if t != "string":
                return t
        default = node.args.get("default")
        if default is not None:
            t = _type_of(default, default_table, catalog)
            if t != "string":
                return t
        return "string"

    # ── IF expression ─────────────────────────────────────────────────────────
    if isinstance(node, exp.If):
        for branch_key in ("true", "false"):
            branch = node.args.get(branch_key)
            if branch is not None:
                t = _type_of(branch, default_table, catalog)
                if t != "string":
                    return t
        return "string"

    # ── GREATEST / LEAST ──────────────────────────────────────────────────────
    if isinstance(node, exp.Greatest) or isinstance(node, exp.Least):
        for arg in node.args.get("expressions", []):
            t = _type_of(arg, default_table, catalog)
            if t != "string":
                return t
        return "string"

    # ── Anonymous function calls (GREATEST/LEAST may also appear here) ────────
    if isinstance(node, exp.Anonymous):
        name = node.name.upper() if node.name else ""
        if name in ("GREATEST", "LEAST"):
            for arg in node.args.get("expressions", []):
                t = _type_of(arg, default_table, catalog)
                if t != "string":
                    return t

    # ── COALESCE / IFNULL / NVL ───────────────────────────────────────────────
    if isinstance(node, exp.Coalesce):
        # sqlglot puts the first argument in .this, the rest in .expressions.
        coalesce_args = []
        if node.args.get("this") is not None:
            coalesce_args.append(node.args["this"])
        coalesce_args.extend(node.args.get("expressions") or [])
        for arg in coalesce_args:
            if isinstance(arg, exp.Literal):
                continue
            t = _type_of(arg, default_table, catalog)
            if t != "string":
                return t
        return "string"

    # ── Arithmetic: propagate from operands ───────────────────────────────────
    if isinstance(node, (exp.Add, exp.Sub, exp.Mul, exp.Div)):
        for side in ("this", "expression"):
            operand = node.args.get(side)
            if operand is not None:
                t = _type_of(operand, default_table, catalog)
                if t != "string":
                    return t

    # ── String functions → string ─────────────────────────────────────────────
    if isinstance(node, (exp.Replace, exp.Trim, exp.Lower, exp.Upper, exp.Concat)):
        return "string"

    # ── Literals ─────────────────────────────────────────────────────────────
    if isinstance(node, exp.Literal):
        if node.is_number:
            return "bigint" if "." not in str(node.this) else "double"
        return "string"

    if isinstance(node, exp.Boolean):
        return "boolean"

    return "string"


# ── CAST target type → string ─────────────────────────────────────────────────

def _cast_type_str(dtype_node: exp.DataType | None) -> str:
    """Convert a sqlglot DataType node (from a CAST) to a dbt type string."""
    if dtype_node is None:
        return "string"

    type_map: dict[exp.DataType.Type, str] = {
        exp.DataType.Type.VARCHAR: "string",
        exp.DataType.Type.TEXT: "string",
        exp.DataType.Type.CHAR: "string",
        exp.DataType.Type.INT: "int",
        exp.DataType.Type.TINYINT: "int",
        exp.DataType.Type.SMALLINT: "int",
        exp.DataType.Type.BIGINT: "bigint",
        exp.DataType.Type.FLOAT: "float",
        exp.DataType.Type.DOUBLE: "double",
        exp.DataType.Type.BOOLEAN: "boolean",
        exp.DataType.Type.DATE: "date",
        exp.DataType.Type.TIMESTAMP: "timestamp(3)",
        exp.DataType.Type.TIMESTAMPTZ: "timestamp(3)",
        exp.DataType.Type.DECIMAL: None,  # handled below with precision/scale
    }

    # DECIMAL(p, s) — format explicitly.
    if dtype_node.this == exp.DataType.Type.DECIMAL:
        params = dtype_node.expressions
        if len(params) == 2:
            return f"decimal({params[0]},{params[1]})"
        if len(params) == 1:
            return f"decimal({params[0]})"
        return "decimal"

    mapped = type_map.get(dtype_node.this)
    if mapped is not None:
        return mapped

    # Fall back to the SQL representation of the type node.
    return dtype_node.sql().lower()
