"""Parse Flink INSERT INTO ... SELECT DML statements."""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class DmlStatement:
    target_table: str
    body: str
    leading_comments: str
    source_file: str


def strip_identifier(name: str) -> str:
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1]
    return name


def parse_dml(sql: str, source_file: str = "") -> DmlStatement:
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    if re.search(r"\bCREATE\s+TABLE\b", sql, re.IGNORECASE) and re.search(
        r"\bAS\s+SELECT\b", sql, re.IGNORECASE
    ):
        raise ValueError("CTAS (CREATE TABLE ... AS SELECT) is not supported")

    insert_match = re.search(
        r"\bINSERT\s+INTO\s+(?P<table>`[^`]+`|\w+)\s*(?P<cols>\([^)]+\))?\s*",
        sql,
        re.IGNORECASE,
    )
    if not insert_match:
        raise ValueError("Expected INSERT INTO ... SELECT statement")

    after_insert = sql[insert_match.end() :]
    if re.match(r"\s*VALUES\b", after_insert, re.IGNORECASE):
        raise ValueError("INSERT INTO ... VALUES is not supported")

    target_table = strip_identifier(insert_match.group("table"))
    leading_comments = sql[: insert_match.start()].strip()
    body = after_insert.strip()
    if not body:
        raise ValueError("INSERT INTO statement has empty SELECT body")

    return DmlStatement(
        target_table=target_table,
        body=body,
        leading_comments=leading_comments,
        source_file=source_file,
    )


def discover_ddl_path(
    dml_path: str,
    target_table: str,
    ddl_file: str | None = None,
) -> str:
    from pathlib import Path

    if ddl_file:
        path = Path(ddl_file).resolve()
        if not path.is_file():
            raise FileNotFoundError(f"DDL file not found: {path}")
        return str(path)

    parent = Path(dml_path).resolve().parent
    stem = Path(dml_path).stem
    if stem.startswith("dml."):
        candidate = parent / f"ddl.{stem[4:]}.sql"
        if candidate.is_file():
            return str(candidate)

    candidate = parent / f"ddl.{target_table}.sql"
    if candidate.is_file():
        return str(candidate)

    raise FileNotFoundError(
        f"No DDL file found for {target_table}. "
        f"Tried ddl.{stem[4:] if stem.startswith('dml.') else target_table}.sql "
        f"in {parent}. Pass --ddl-file explicitly."
    )
