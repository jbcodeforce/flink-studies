#!/usr/bin/env python3
"""Parse a dbt SQL model and emit a ready-to-paste ``models:`` YAML block.

Resolves column names and data types by:

1. Stripping Jinja templating and parsing the SQL with sqlglot.
2. Walking upstream ``{{ ref('...') }}`` models to load their column
   definitions from YAML files (recursively expanding ``SELECT *`` chains).
3. Inferring types for each output column — handles ``CAST``, ``GREATEST``,
   ``COALESCE``, plain pass-throughs, and aliases.

The output is printed to stdout in the same format produced by
``sr_to_dbt_yaml.py --output model``.

Examples::

    # Auto-detect project root (walks up to find dbt_project.yml)
    uv run sql_to_dbt_yaml.py ../airbnb_streaming/models/user_reviews/dimensions/dim_listings_with_hosts.sql

    # Explicit project root
    uv run sql_to_dbt_yaml.py path/to/model.sql --project-root ../airbnb_streaming

    # Override the model name in the YAML output
    uv run sql_to_dbt_yaml.py path/to/model.sql --model-name my_custom_name
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Shared-library discovery (same pattern as sr_to_dbt_yaml.py)
# ---------------------------------------------------------------------------

def _cm_py_lib_root() -> Path:
    """Walk parent directories to locate code/flink-sql/cm_py_lib."""
    marker = Path("code") / "flink-sql" / "cm_py_lib" / "schema_registry.py"
    for parent in Path(__file__).resolve().parents:
        candidate = parent / marker
        if candidate.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib/schema_registry.py. "
        "Run inside the flink-studies repo."
    )


def _setup_cm_py_lib() -> None:
    root = _cm_py_lib_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))


def _setup_tools_dir() -> None:
    """Ensure the tools/ directory (where sql_parser etc. live) is on sys.path."""
    tools_dir = str(Path(__file__).parent.resolve())
    if tools_dir not in sys.path:
        sys.path.insert(0, tools_dir)


# ---------------------------------------------------------------------------
# Project-root detection
# ---------------------------------------------------------------------------

def _find_project_root(sql_path: Path) -> Path:
    """Walk from *sql_path* upward until ``dbt_project.yml`` is found."""
    for parent in sql_path.resolve().parents:
        if (parent / "dbt_project.yml").is_file():
            return parent
    raise FileNotFoundError(
        f"Could not find dbt_project.yml above '{sql_path}'. "
        "Use --project-root to specify the dbt project directory explicitly."
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Parse a dbt SQL model and emit a models: YAML block.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "sql_file",
        help="Path to the dbt SQL model file (e.g. dim_listings_with_hosts.sql).",
    )
    parser.add_argument(
        "--project-root",
        default="",
        metavar="DIR",
        help=(
            "Path to the dbt project root (directory containing dbt_project.yml). "
            "Defaults to auto-detection by walking up from the SQL file."
        ),
    )
    parser.add_argument(
        "--model-name",
        default="",
        metavar="NAME",
        help=(
            "Override the model name used in the YAML output. "
            "Defaults to the SQL file's stem (e.g. 'dim_listings_with_hosts')."
        ),
    )
    parser.add_argument(
        "--yaml",
        action="store_true",
        default=False,
        help=(
            "Write the YAML output to a file next to the SQL file "
            "(e.g. dim_listings_with_hosts.yml) instead of printing to stdout."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    _setup_cm_py_lib()
    _setup_tools_dir()

    # Import after sys.path is patched.
    from cm_py_lib.schema_registry import render_model_yaml  # noqa: PLC0415
    from sql_parser import parse_select  # noqa: PLC0415
    from model_resolver import ModelResolver, ColumnSpec, _extract_cte_alias_map  # noqa: PLC0415
    from type_inferrer import infer_type  # noqa: PLC0415

    args = build_arg_parser().parse_args(argv)

    sql_path = Path(args.sql_file)
    if not sql_path.is_file():
        print(f"Error: SQL file not found: '{sql_path}'", file=sys.stderr)
        return 1

    # Resolve project root.
    try:
        if args.project_root:
            project_root = Path(args.project_root).resolve()
            if not project_root.is_dir():
                print(
                    f"Error: --project-root directory not found: '{project_root}'",
                    file=sys.stderr,
                )
                return 1
        else:
            project_root = _find_project_root(sql_path)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    model_name = args.model_name or sql_path.stem

    # ── Parse the SQL file ────────────────────────────────────────────────────
    sql = sql_path.read_text()

    try:
        select_items = parse_select(sql)
    except Exception as exc:  # noqa: BLE001
        print(f"Error: Failed to parse SQL: {exc}", file=sys.stderr)
        return 1

    if not select_items:
        print(
            f"Error: No SELECT columns found in '{sql_path}'.", file=sys.stderr
        )
        return 1

    # ── Build the column catalog ──────────────────────────────────────────────
    # Map every CTE alias (and direct table alias) to its upstream model,
    # then resolve each model's columns via ModelResolver.
    resolver = ModelResolver(project_root)

    try:
        cte_alias_map = _extract_cte_alias_map(sql)
    except Exception as exc:  # noqa: BLE001
        print(f"Error: Failed to extract CTE aliases: {exc}", file=sys.stderr)
        return 1

    catalog: dict[str, dict[str, str]] = {}
    for alias, ref_model in cte_alias_map.items():
        try:
            upstream_cols = resolver.get_columns(ref_model)
        except Exception as exc:  # noqa: BLE001
            print(
                f"Warning: Could not resolve columns for model '{ref_model}': {exc}",
                file=sys.stderr,
            )
            upstream_cols = []
        col_map = {c.name: c.data_type for c in upstream_cols}
        catalog[alias] = col_map
        # Register the model name itself in case it appears without an alias.
        catalog.setdefault(ref_model, col_map)

    # ── Resolve output columns ────────────────────────────────────────────────
    output_columns: list[ColumnSpec] = []
    for item in select_items:
        if item.output_name == "*":
            # Expand SELECT * — flatten all catalog entries.
            seen: dict[str, str] = {}
            for cols in catalog.values():
                for n, t in cols.items():
                    seen.setdefault(n, t)
            for n, t in seen.items():
                output_columns.append(ColumnSpec(name=n, data_type=t))
        else:
            dtype = infer_type(item, catalog)
            output_columns.append(ColumnSpec(name=item.output_name, data_type=dtype))

    if not output_columns:
        print("Error: Could not derive any output columns.", file=sys.stderr)
        return 1

    # ── Render and emit ───────────────────────────────────────────────────────
    # render_model_yaml expects objects with .name and .data_type attributes.
    yaml_text = render_model_yaml(model_name, output_columns)

    if args.yaml:
        out_path = sql_path.with_suffix(".yml")
        out_path.write_text(yaml_text)
        print(f"Written to {out_path}", file=sys.stderr)
    else:
        print(yaml_text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
