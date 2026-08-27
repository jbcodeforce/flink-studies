"""Parse Flink CREATE TABLE DDL statements."""

from __future__ import annotations

import re
from dataclasses import dataclass, field


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


def strip_identifier(name: str) -> str:
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1]
    return name


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
