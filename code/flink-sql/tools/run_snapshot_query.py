#!/usr/bin/env python3
"""
Run a snapshot query against a Flink table on Confluent Cloud (confluent-sql REST API).

Examples:
  uv run python run_snapshot_query.py --table orders --limit 10
  uv run python run_snapshot_query.py --table orders --columns "order_id, amount" --where "amount > 100"
  uv run python run_snapshot_query.py --sql "SELECT COUNT(*) AS cnt FROM orders" --output json
"""

from __future__ import annotations

import argparse
import sys

from cc_flink_deploy import (
    STATEMENT_TIMEOUT_SEC,
    build_select_sql,
    default_snapshot_statement_name,
    load_dotenv_file,
    print_snapshot_result,
    run_snapshot_query,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a snapshot query on a Confluent Cloud Flink table."
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument(
        "--table",
        help="Table to query (simple name or fully qualified identifier)",
    )
    target.add_argument(
        "--sql",
        help="Full SQL to run as a snapshot query (overrides --table builder options)",
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
        help="Optional Flink statement name (default: snapshot-<table>-<timestamp>)",
    )
    parser.add_argument(
        "--output",
        choices=("table", "json", "csv"),
        default="table",
        help="Output format (default: table)",
    )
    parser.add_argument(
        "--as-dict",
        action="store_true",
        help="Fetch rows as dicts internally (json output always uses column names)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=STATEMENT_TIMEOUT_SEC,
        help=f"Statement timeout in seconds (default: {STATEMENT_TIMEOUT_SEC})",
    )
    parser.add_argument(
        "--keep-statement",
        action="store_true",
        help="Do not delete the Flink statement after fetching results",
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
        statement_name = args.statement_name or default_snapshot_statement_name("custom")
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
        statement_name = args.statement_name or default_snapshot_statement_name(args.table)

    try:
        result = run_snapshot_query(
            sql,
            statement_name=statement_name,
            as_dict=args.as_dict,
            timeout=args.timeout,
            delete_statement=not args.keep_statement,
        )
    except (RuntimeError, ValueError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    print_snapshot_result(
        result,
        output=args.output,
        show_meta=not args.quiet_meta,
    )


if __name__ == "__main__":
    main()
