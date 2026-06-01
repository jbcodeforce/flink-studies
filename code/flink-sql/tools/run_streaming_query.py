#!/usr/bin/env python3
"""
Run a streaming query against a Flink table on Confluent Cloud (confluent-sql REST API).

Examples:
  uv run python run_streaming_query.py --table orders
  uv run python run_streaming_query.py --sql "SELECT * FROM orders WHERE amount > 100"
  uv run python run_streaming_query.py --table orders --max-rows 20 --output json
"""

from __future__ import annotations

import argparse
import sys

from cc_flink_deploy import (
    STATEMENT_TIMEOUT_SEC,
    build_select_sql,
    default_streaming_statement_name,
    load_dotenv_file,
    run_streaming_query,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a streaming query on a Confluent Cloud Flink table."
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument(
        "--table",
        help="Table to query (simple name or fully qualified identifier)",
    )
    target.add_argument(
        "--sql",
        help="Full SQL to run as a streaming query (overrides --table builder options)",
    )

    parser.add_argument(
        "--columns",
        default="*",
        help="Column list for generated SELECT when using --table (default: *)",
    )
    parser.add_argument(
        "--where",
        default=None,
        help="Optional WHERE clause (without the WHERE keyword) for --table",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional LIMIT for generated SELECT when using --table",
    )
    parser.add_argument(
        "--statement-name",
        default=None,
        help="Optional Flink statement name (default: stream-<table>-<timestamp>)",
    )
    parser.add_argument(
        "--output",
        choices=("table", "json", "csv"),
        default="table",
        help="Per-row output format (default: table)",
    )
    parser.add_argument(
        "--as-dict",
        action="store_true",
        help="Fetch rows as dicts internally",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=STATEMENT_TIMEOUT_SEC,
        help=f"Statement startup timeout in seconds (default: {STATEMENT_TIMEOUT_SEC})",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=None,
        help="Stop after printing this many rows (default: run until Ctrl+C)",
    )
    parser.add_argument(
        "--keep-statement",
        action="store_true",
        help="Do not delete the Flink statement after stopping",
    )
    parser.add_argument(
        "--quiet-meta",
        action="store_true",
        help="Suppress statement metadata on stderr",
    )
    return parser.parse_args()


def main() -> None:
    load_dotenv_file()
    args = parse_args()

    if args.sql:
        sql = args.sql.strip()
        statement_name = args.statement_name or default_streaming_statement_name("custom")
    else:
        try:
            sql = build_select_sql(
                args.table,
                columns=args.columns,
                limit=args.limit,
                where=args.where,
            )
        except ValueError as exc:
            print(exc, file=sys.stderr)
            sys.exit(1)
        statement_name = args.statement_name or default_streaming_statement_name(args.table)

    try:
        run_streaming_query(
            sql,
            statement_name=statement_name,
            as_dict=args.as_dict,
            timeout=args.timeout,
            output=args.output,
            max_rows=args.max_rows,
            show_meta=not args.quiet_meta,
            delete_statement=not args.keep_statement,
        )
    except (RuntimeError, ValueError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
