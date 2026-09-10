"""Parse Flink SQL DML statements (INSERT INTO … SELECT and CREATE TABLE … AS SELECT)."""

from __future__ import annotations

import re
from pathlib import Path
from dataclasses import dataclass, field
import logging

# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

def _get_logger() -> logging.Logger:
    logger = logging.getLogger("mig_to_dbt")
    if not logger.handlers:
        logger.setLevel(logging.DEBUG)
        log_path = Path("logs") / "mig_to_dbt.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(log_path, encoding="utf-8")
        handler.setFormatter(
            logging.Formatter("%(asctime)s  %(levelname)-8s  %(message)s",
                              datefmt="%Y-%m-%d %H:%M:%S")
        )
        logger.addHandler(handler)
    return logger

logger = _get_logger()

# ==========================
# Models
# ==========================
@dataclass(frozen=True)
class DmlStatement:
    target_table: str
    body: str
    leading_comments: str
    with_options: dict[str, str]    # options from the optional WITH (…) clause on the CREATE TABLE
    source_file: str

@dataclass(frozen=True)
class ValuesDmlStatement:
    target_table: str
    columns: list[str]
    rows: list[list[str | None]]
    source_file: str


@dataclass(frozen=True)
class DdlColumn:
    name: str
    flink_type: str
    not_null: bool = False


@dataclass
class DdlTable:
    table_name: str
    columns: list[DdlColumn] = field(default_factory=list)
    distributed_by: str | None = None
    with_options: dict[str, str] = field(default_factory=dict)
    primary_key: list[str] = field(default_factory=list)



# ==========================
# Private APIs
# ==========================
def _match_insert_into(sql: str) -> re.Match[str] | None:
    return re.search(
        r"\bINSERT\s+INTO\s+(?P<table>`[^`]+`|\w+)\s*(?P<cols>\([^)]+\))?\s*",
        sql,
        re.IGNORECASE,
    )


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



def _extract_balanced(text: str, open_index: int) -> tuple[str, int]:
    if open_index >= len(text) or text[open_index] != "(":
        raise ValueError("Expected opening parenthesis")

    depth = 0
    angle_depth = 0
    start = open_index + 1
    for index in range(open_index, len(text)):
        char = text[index]
        if char == "<":
            angle_depth += 1
        elif char == ">":
            angle_depth -= 1
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return text[start:index], index + 1
    raise ValueError("Unbalanced parentheses in CREATE TABLE")


def _strip_sql_comments(sql: str) -> str:
    return "\n".join(re.sub(r"--.*$", "", line) for line in sql.splitlines())


def _split_definitions(body: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    angle_depth = 0
    paren_depth = 0

    for char in body:
        if char == "<":
            angle_depth += 1
        elif char == ">":
            angle_depth -= 1
        elif char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
        elif char == "," and angle_depth == 0 and paren_depth == 0:
            piece = "".join(current).strip()
            if piece:
                parts.append(piece)
            current = []
            continue
        current.append(char)

    piece = "".join(current).strip()
    if piece:
        parts.append(piece)
    return parts


def _parse_column_definition(defn: str) -> DdlColumn | None:
    stripped = re.sub(r"--.*$", "", defn).strip()
    if re.match(r"PRIMARY\s+KEY\b", stripped, re.IGNORECASE):
        return None
    if re.match(r"WATERMARK\s+FOR\b", stripped, re.IGNORECASE):
        return None
    if re.match(r"CONSTRAINT\b", stripped, re.IGNORECASE):
        return None

    not_null = bool(re.search(r"\bNOT\s+NULL\b", stripped, re.IGNORECASE))
    type_part = re.sub(r"\bNOT\s+NULL\b", "", stripped, flags=re.IGNORECASE).strip()

    name_match = re.match(r"(`[^`]+`|\w+)\s+(.+)", type_part, re.DOTALL)
    if not name_match:
        raise ValueError(f"Could not parse column definition: {defn}")

    name = strip_identifier(name_match.group(1))
    flink_type = name_match.group(2).strip()
    return DdlColumn(name=name, flink_type=flink_type, not_null=not_null)


def _parse_with_options(sql: str) -> dict[str, str]:
    matches = list(re.finditer(r"\bWITH\s*\(", sql, re.IGNORECASE))
    if not matches:
        return {}

    open_paren = matches[-1].end() - 1
    body, _ = _extract_balanced(sql, open_paren)
    options: dict[str, str] = {}
    for part in _split_definitions(body):
        option_match = re.match(
            r"'([^']+)'\s*=\s*'([^']*)'",
            part.strip(),
        )
        if option_match:
            options[option_match.group(1)] = option_match.group(2)
    return options


def _parse_primary_key(columns_body: str) -> list[str]:
    match = re.search(
        r"PRIMARY\s+KEY\s*\(([^)]+)\)",
        columns_body,
        re.IGNORECASE,
    )
    if not match:
        return []
    return [
        strip_identifier(part.strip())
        for part in match.group(1).split(",")
        if part.strip()
    ]


# ==========================
# Public APIs
# ==========================

def is_ctas(sql: str) -> bool:
    """Return True if *sql* is a ``CREATE TABLE … AS SELECT`` statement."""
    sql_stripped = sql.strip()
    if sql_stripped.endswith(";"):
        sql_stripped = sql_stripped[:-1].rstrip()
    return bool(
        re.search(r"\bCREATE\s+TABLE\b", sql_stripped, re.IGNORECASE)
        and re.search(r"\bAS\s+(?:WITH\b|SELECT\b)", sql_stripped, re.IGNORECASE)
    )


def strip_identifier(name: str) -> str:
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1]
    return name

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



def parse_ddl(sql: str) -> DdlTable:
    create_match = re.search(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?P<table>`[^`]+`|\w+)\s*\(",
        sql,
        re.IGNORECASE,
    )
    if not create_match:
        raise ValueError("Expected CREATE TABLE statement")

    table_name = strip_identifier(create_match.group("table"))
    open_paren = create_match.end() - 1
    columns_body, _ = _extract_balanced(sql, open_paren)
    columns_body = _strip_sql_comments(columns_body)

    columns: list[DdlColumn] = []
    for definition in _split_definitions(columns_body):
        column = _parse_column_definition(definition)
        if column is not None:
            columns.append(column)

    distributed_match = re.search(
        r"DISTRIBUTED\s+BY\s+HASH\s*\(([^)]+)\)",
        sql,
        re.IGNORECASE,
    )
    distributed_by = (
        distributed_match.group(1).strip() if distributed_match else None
    )

    return DdlTable(
        table_name=table_name,
        columns=columns,
        distributed_by=distributed_by,
        with_options=_parse_with_options(sql),
        primary_key=_parse_primary_key(columns_body),
    )


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


def parse_ctas(sql: str, source_file: str = "") -> DmlStatement:
    """Parse a ``CREATE TABLE [IF NOT EXISTS] <name> [WITH (…)] AS <body>`` statement.

    *body* is everything after the ``AS`` keyword — either a plain ``SELECT …``
    or ``WITH <ctes> … SELECT …``.  Leading preamble (e.g. ``ALTER TABLE`` or
    ``-- comments``) before the ``CREATE TABLE`` is captured in
    ``leading_comments``.
    """
    logger.info(f"sql: {sql} in src: {source_file}")
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    # Step 1: find CREATE TABLE [IF NOT EXISTS] <name>
    header_match = re.search(
        r"\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?P<table>`[^`]+`|\w+)",
        sql,
        re.IGNORECASE,
    )
    if not header_match:
        raise ValueError("Expected CREATE TABLE … AS statement")

    target_table = strip_identifier(header_match.group("table"))
    leading_comments = sql[: header_match.start()].strip()

    # Step 2: after the table name, optionally skip a column-definition block
    # (e.g. ``create table t (col TYPE, PRIMARY KEY …)``) then optionally
    # consume a WITH (…) options block.
    pos = header_match.end()
    with_options: dict[str, str] = {}

    # skip optional column-definition block: ``(col TYPE, …)`` immediately
    # after the table name (before the WITH options or the AS keyword).
    # We detect it by finding the opening '(' offset and checking that the
    # token right after the matching ')' is WITH or AS.
    paren_offset = len(sql[pos:]) - len(sql[pos:].lstrip())
    if pos + paren_offset < len(sql) and sql[pos + paren_offset] == "(":
        _inner, after_col_paren = _extract_balanced(sql, pos + paren_offset)
        rest_after = sql[after_col_paren:].lstrip()
        if re.match(r"(?:WITH|AS)\b", rest_after, re.IGNORECASE):
            pos = after_col_paren

    with_kw = re.match(r"\s*WITH\s*(?=\()", sql[pos:], re.IGNORECASE)
    if with_kw:
        paren_pos = pos + with_kw.end()
        with_body, after_paren = _extract_balanced(sql, paren_pos)
        with_options = _parse_with_options("WITH (" + with_body + ")")
        pos = after_paren

    # Step 3: expect AS
    as_match = re.match(r"\s+AS\b", sql[pos:], re.IGNORECASE)
    if not as_match:
        raise ValueError("Expected CREATE TABLE … AS statement")

    body = sql[pos + as_match.end():].strip()
    if not body:
        raise ValueError("CTAS statement has empty SELECT body")

    return DmlStatement(
        target_table=target_table,
        body=body,
        leading_comments=leading_comments,
        with_options=with_options,
        source_file=source_file,
    )


def parse_dml(sql: str, source_file: str = "") -> DmlStatement:
    sql = sql.strip()
    if sql.endswith(";"):
        sql = sql[:-1].rstrip()

    if is_ctas(sql):
        return parse_ctas(sql= sql, source_file=source_file)

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
        with_options = {},
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



def collect_cte_names(body: str) -> set[str]:
    """
    Given a SQL query in body, extract the name of CTEs. 
    Returns  set of unique namnes
    """
    stripped = body.lstrip()
    if not re.match(r"WITH\b", stripped, re.IGNORECASE):
        return set()

    names: set[str] = set()
    pos = re.match(r"WITH\s+", stripped, re.IGNORECASE).end()
    rest = stripped[pos:]

    while rest:
        match = re.match(r"(`[^`]+`|[\w]+)\s+AS\s+\(", rest, re.IGNORECASE)
        if not match:
            break

        names.add(strip_identifier(match.group(1)))
        open_paren = match.end() - 1
        depth = 0
        index = open_paren
        while index < len(rest):
            char = rest[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    index += 1
                    break
            index += 1

        rest = rest[index:].lstrip()
        if rest.startswith(","):
            rest = rest[1:].lstrip()
            continue
        break

    return names