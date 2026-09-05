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


@dataclass(frozen=True)
class ValuesDmlStatement:
    target_table: str
    columns: list[str]
    rows: list[list[str | None]]
    source_file: str


def strip_identifier(name: str) -> str:
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1]
    return name


def _match_insert_into(sql: str) -> re.Match[str] | None:
    return re.search(
        r"\bINSERT\s+INTO\s+(?P<table>`[^`]+`|\w+)\s*(?P<cols>\([^)]+\))?\s*",
        sql,
        re.IGNORECASE,
    )


def is_values_insert(sql: str) -> bool:
    """Return True if *sql* is an ``INSERT INTO ... VALUES`` statement."""
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    insert_match = _match_insert_into(sql)
    if not insert_match:
        return False

    after_insert = sql[insert_match.end() :]
    return bool(re.match(r"\s*VALUES\b", after_insert, re.IGNORECASE))


def _split_top_level(text: str, delimiter: str = ",") -> list[str]:
    """Split *text* on *delimiter* at paren-depth 0, outside single-quoted strings.

    Handles the SQL ``''`` doubled-quote escape inside string literals.
    """
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    in_string = False
    index = 0
    length = len(text)

    while index < length:
        char = text[index]
        if in_string:
            if char == "'":
                if index + 1 < length and text[index + 1] == "'":
                    current.append("''")
                    index += 2
                    continue
                in_string = False
            current.append(char)
            index += 1
            continue

        if char == "'":
            in_string = True
            current.append(char)
        elif char == "(":
            depth += 1
            current.append(char)
        elif char == ")":
            depth -= 1
            current.append(char)
        elif char == delimiter and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
        index += 1

    parts.append("".join(current))
    return parts


def _split_top_level_tuples(text: str) -> list[str]:
    """Extract the inner content of each top-level ``(...)`` tuple in *text*."""
    tuples: list[str] = []
    depth = 0
    in_string = False
    start: int | None = None
    index = 0
    length = len(text)

    while index < length:
        char = text[index]
        if in_string:
            if char == "'":
                if index + 1 < length and text[index + 1] == "'":
                    index += 2
                    continue
                in_string = False
            index += 1
            continue

        if char == "'":
            in_string = True
        elif char == "(":
            if depth == 0:
                start = index + 1
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0 and start is not None:
                tuples.append(text[start:index])
                start = None
        index += 1

    return tuples


_TYPED_LITERAL_RE = re.compile(
    r"^(?:DATE|TIME|TIMESTAMP)\s*'(?P<value>.*)'$",
    re.IGNORECASE | re.DOTALL,
)
_STRING_LITERAL_RE = re.compile(r"^'(?P<value>.*)'$", re.DOTALL)


def clean_sql_literal(token: str) -> str | None:
    """Convert a single SQL literal token to a plain CSV cell value.

    Handles ``NULL``, typed literals (``DATE '...'``, ``TIMESTAMP '...'``),
    quoted strings (unescaping ``''``), and passes through bare numeric /
    boolean tokens unchanged.
    """
    token = token.strip()

    if token.upper() == "NULL":
        return None

    typed_match = _TYPED_LITERAL_RE.match(token)
    if typed_match:
        return typed_match.group("value").replace("''", "'")

    string_match = _STRING_LITERAL_RE.match(token)
    if string_match:
        return string_match.group("value").replace("''", "'")

    return token


def parse_values_dml(sql: str, source_file: str = "") -> ValuesDmlStatement:
    """Parse an ``INSERT INTO <table> (<cols>) VALUES (...), (...), ...`` statement."""
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    insert_match = _match_insert_into(sql)
    if not insert_match:
        raise ValueError("Expected INSERT INTO ... VALUES statement")

    target_table = strip_identifier(insert_match.group("table"))
    # Column list is optional: `INSERT INTO t VALUES (...)` relies on DDL column
    # order, resolved later by the caller once the companion DDL is parsed.
    columns = (
        [
            strip_identifier(col)
            for col in insert_match.group("cols")[1:-1].split(",")
            if col.strip()
        ]
        if insert_match.group("cols")
        else []
    )

    after_insert = sql[insert_match.end() :]
    values_match = re.match(r"\s*VALUES\b", after_insert, re.IGNORECASE)
    if not values_match:
        raise ValueError("Expected VALUES clause after INSERT INTO")

    tuples_text = after_insert[values_match.end() :]
    row_tuples = _split_top_level_tuples(tuples_text)
    if not row_tuples:
        raise ValueError("INSERT INTO ... VALUES statement has no rows")

    rows: list[list[str | None]] = []
    expected_len = len(columns) if columns else None
    for row_text in row_tuples:
        cells = [clean_sql_literal(cell) for cell in _split_top_level(row_text)]
        if expected_len is None:
            expected_len = len(cells)
        elif len(cells) != expected_len:
            raise ValueError(
                f"Row has {len(cells)} values but {expected_len} were expected: {row_text!r}"
            )
        rows.append(cells)

    return ValuesDmlStatement(
        target_table=target_table,
        columns=columns,
        rows=rows,
        source_file=source_file,
    )


def parse_dml(sql: str, source_file: str = "") -> DmlStatement:
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    if re.search(r"\bCREATE\s+TABLE\b", sql, re.IGNORECASE) and re.search(
        r"\bAS\s+SELECT\b", sql, re.IGNORECASE
    ):
        raise ValueError("CTAS (CREATE TABLE ... AS SELECT) is not supported")

    insert_match = _match_insert_into(sql)
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
