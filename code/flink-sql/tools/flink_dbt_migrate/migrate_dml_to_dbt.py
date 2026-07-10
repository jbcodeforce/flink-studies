#!/usr/bin/env python3
"""Migrate Flink INSERT INTO DML statements to dbt streaming_table models."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from flink_dbt_migrate.migrate import migrate_dml_to_dbt



def parse_ref_table(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise argparse.ArgumentTypeError(
            f"Expected TABLE=MODEL mapping, got: {value!r}"
        )
    table, model = value.split("=", 1)
    table = table.strip()
    model = model.strip()
    if not table or not model:
        raise argparse.ArgumentTypeError(
            f"Expected TABLE=MODEL mapping, got: {value!r}"
        )
    return table, model


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "statement_file",
        type=Path,
        help="Flink DML file (INSERT INTO ... SELECT)",
    )
    parser.add_argument(
        "target_dir",
        type=Path,
        help="dbt models subfolder to write {model}.sql and schema.yml",
    )
    parser.add_argument(
        "--ddl-file",
        type=Path,
        default=None,
        help="Override auto-discovered DDL file",
    )
    parser.add_argument(
        "--model-name",
        default=None,
        help="Output model name (default: INSERT INTO target table)",
    )
    parser.add_argument(
        "--materialized",
        default="streaming_table",
        help="dbt materialization (default: streaming_table)",
    )
    parser.add_argument(
        "--ref-table",
        action="append",
        default=[],
        type=parse_ref_table,
        metavar="TABLE=MODEL",
        help="Override {{ ref() }} mapping for an upstream table",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write output files (default: dry-run to stdout)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing model and replace schema.yml entry",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 if output would change (for CI)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.statement_file.is_file():
        print(f"Statement file not found: {args.statement_file}", file=sys.stderr)
        return 1

    ref_overrides = dict(args.ref_table)

    try:
        result = migrate_dml_to_dbt(
            args.statement_file,
            args.target_dir,
            ddl_file=args.ddl_file,
            model_name=args.model_name,
            materialized=args.materialized,
            ref_overrides=ref_overrides,
            force=args.force,
        )
    except (ValueError, FileNotFoundError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    existing_model = (
        result.model_path.read_text(encoding="utf-8")
        if result.model_path.exists()
        else ""
    )
    existing_schema = (
        result.schema_path.read_text(encoding="utf-8")
        if result.schema_path.exists()
        else ""
    )

    would_change = (
        existing_model != result.model_sql or existing_schema != result.schema_yml
    )

    if args.check and would_change:
        print(
            f"Output differs from {result.model_path} / {result.schema_path}; "
            "run with --write",
            file=sys.stderr,
        )
        return 1

    if args.write:
        args.target_dir.mkdir(parents=True, exist_ok=True)
        if result.model_path.exists() and not args.force:
            print(
                f"Model already exists: {result.model_path} (use --force to overwrite)",
                file=sys.stderr,
            )
            return 1
        result.model_path.write_text(result.model_sql, encoding="utf-8")
        result.schema_path.write_text(result.schema_yml, encoding="utf-8")
        print(f"Wrote {result.model_path}")
        print(f"Wrote {result.schema_path}")
        print(f"DDL source: {result.ddl_path}", file=sys.stderr)
        return 0

    print("# --- model ---")
    print(result.model_sql, end="")
    print("# --- schema.yml ---")
    print(result.schema_yml, end="")
    print(f"# DDL source: {result.ddl_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
