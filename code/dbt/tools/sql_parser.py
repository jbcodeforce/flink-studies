"""Parse dbt SQL files into structured column references.

Strips Jinja templating ({{ config(...) }} blocks and {{ ref('...') }} calls)
to produce plain SQL that can be fed to sqlglot, then walks the AST to extract:

- ``extract_refs``   — all upstream model names referenced via ``{{ ref('…') }}``
- ``parse_select``   — the final SELECT's output column list as ``SelectItem``s

``SelectItem`` carries enough information for the type inferrer:
  - ``output_name``   — the column name that appears in the output (alias or derived)
  - ``table_alias``   — the CTE / table qualifier (e.g. ``l`` in ``l.listing_id``)
  - ``col_name``      — the bare source column (or None for expressions)
  - ``expression``    — the sqlglot AST node for the full expression
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

import sqlglot
import sqlglot.expressions as exp


# ── Jinja stripping ───────────────────────────────────────────────────────────

_CONFIG_RE = re.compile(
    r"\{\{-?\s*config\s*\(.*?\)\s*-?\}\}",
    re.DOTALL | re.IGNORECASE,
)

_REF_RE = re.compile(
    r"""\{\{-?\s*ref\s*\(\s*['"]([^'"]+)['"]\s*\)\s*-?\}\}""",
    re.IGNORECASE,
)

# {{ source('schema', 'table') }} — replace with just the table name.
_SOURCE_RE = re.compile(
    r"""\{\{-?\s*source\s*\(\s*['"][^'"]+['"]\s*,\s*['"]([^'"]+)['"]\s*\)\s*-?\}\}""",
    re.IGNORECASE,
)

# Backtick-quoted identifiers (MySQL style) → double-quoted (standard SQL).
_BACKTICK_RE = re.compile(r"`([^`]+)`")


def strip_jinja_config(sql: str) -> str:
    """Remove ``{{ config(...) }}`` blocks from *sql*, returning plain SQL."""
    return _CONFIG_RE.sub("", sql).strip()


def extract_refs(sql: str) -> list[str]:
    """Return all model names referenced via ``{{ ref('name') }}`` in *sql*."""
    return _REF_RE.findall(sql)


def _replace_refs(sql: str) -> str:
    """Replace ``{{ ref('model') }}`` and ``{{ source('s','t') }}`` tokens with
    the bare identifier (model name / table name), and normalise backtick
    identifiers to double-quoted identifiers for sqlglot compatibility.

    This makes the SQL parseable by sqlglot while preserving table references
    so the AST still carries CTE/join structure.
    """
    sql = _REF_RE.sub(lambda m: m.group(1), sql)
    sql = _SOURCE_RE.sub(lambda m: m.group(1), sql)
    sql = _BACKTICK_RE.sub(lambda m: f'"{m.group(1)}"', sql)
    return sql


# ── SelectItem ────────────────────────────────────────────────────────────────

@dataclass
class SelectItem:
    """One column in the outermost SELECT list.

    Attributes:
        output_name:  The name this column will have in the output model.
        table_alias:  The CTE or table qualifier (``l`` in ``l.listing_id``),
                      or ``None`` when not present.
        col_name:     The bare column name being selected (``listing_id``),
                      or ``None`` for pure expressions.
        expression:   The raw sqlglot AST node for the whole expression.
    """
    output_name: str
    table_alias: str | None
    col_name: str | None
    expression: Any = field(repr=False)


# ── SQL → SelectItem list ─────────────────────────────────────────────────────

def parse_select(sql: str) -> list[SelectItem]:
    """Parse *sql* and return the SELECT items of the outermost query.

    *sql* may contain Jinja ``{{ config(...) }}`` and ``{{ ref('…') }}`` tokens;
    they are stripped / replaced before parsing.

    Returns an ordered list of :class:`SelectItem`.
    """
    cleaned = strip_jinja_config(sql)
    cleaned = _replace_refs(cleaned)

    # sqlglot dialect: use the generic dialect (no vendor-specific keywords).
    statement = sqlglot.parse_one(cleaned)
    if statement is None:
        return []

    # Walk to the outermost SELECT — handles WITH … SELECT … wrapping.
    select_node = _outermost_select(statement)
    if select_node is None:
        return []

    items: list[SelectItem] = []
    for expr in select_node.expressions:
        items.append(_to_select_item(expr))
    return items


def _outermost_select(node: exp.Expression) -> exp.Select | None:
    """Return the outermost SELECT node in *node*, or None."""
    # A WITH clause wraps its body as the last CTE body — the final query is
    # accessible via .this on a With node, which is the final SELECT.
    if isinstance(node, exp.With):
        return _outermost_select(node.this)
    if isinstance(node, exp.Select):
        return node
    # Subquery wrappers
    if isinstance(node, exp.Subquery):
        return _outermost_select(node.this)
    # Try .this for other wrapper types (e.g. CTAS)
    inner = getattr(node, "this", None)
    if inner is not None:
        return _outermost_select(inner)
    return None


def _to_select_item(expr: exp.Expression) -> SelectItem:
    """Convert a single SELECT expression node to a :class:`SelectItem`."""
    # Determine the alias / output name.
    if isinstance(expr, exp.Alias):
        output_name = expr.alias  # the string alias
        inner = expr.this         # the expression being aliased
    else:
        output_name = _derive_name(expr)
        inner = expr

    # Extract table qualifier and bare column name for simple column refs.
    table_alias: str | None = None
    col_name: str | None = None

    if isinstance(inner, exp.Column):
        col_name = inner.name
        tbl = inner.table
        if tbl:
            table_alias = tbl

    return SelectItem(
        output_name=output_name,
        table_alias=table_alias,
        col_name=col_name,
        expression=inner,
    )


def _derive_name(expr: exp.Expression) -> str:
    """Derive a column output name from an expression with no explicit alias."""
    if isinstance(expr, exp.Column):
        return expr.name
    if isinstance(expr, exp.Star):
        return "*"
    # For any other expression, use the SQL text as a last resort.
    return expr.sql()
