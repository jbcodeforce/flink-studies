"""Rewrite bare Flink table names to dbt {{ ref() }} or {{ source() }} calls."""

from __future__ import annotations

import re


def strip_identifier(name: str) -> str:
    name = name.strip()
    if name.startswith("`") and name.endswith("`"):
        return name[1:-1]
    return name


def collect_cte_names(body: str) -> set[str]:
    stripped = body.lstrip()
    if not re.match(r"WITH\b", stripped, re.IGNORECASE):
        return set()

    names: set[str] = set()
    pos = re.match(r"WITH\s+", stripped, re.IGNORECASE).end()
    rest = stripped[pos:]

    while rest:
        match = re.match(r"(`?[\w]+`?)\s+AS\s+\(", rest, re.IGNORECASE)
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


def rewrite_refs(
    sql: str,
    cte_names: set[str],
    ref_overrides: dict[str, str] | None = None,
    ref_tables: set[str] | None = None,
    source_tables: dict[str, str] | None = None,
) -> str:
    ref_overrides = ref_overrides or {}
    ref_tables = ref_tables or set()
    source_tables = source_tables or {}

    def should_rewrite(table: str) -> bool:
        clean = strip_identifier(table)
        return clean not in cte_names

    def rewrite_target(table: str) -> str | None:
        clean = strip_identifier(table)
        if clean in source_tables:
            source_name = source_tables[clean]
            return f"{{{{ source('{source_name}', '{clean}') }}}}"
        if clean in ref_tables or clean in ref_overrides or not source_tables:
            model = ref_overrides.get(clean, clean)
            return f"{{{{ ref('{model}') }}}}"
        return None

    def replace_table_ref(match: re.Match[str]) -> str:
        prefix = match.group(1)
        table = match.group(2)
        if not should_rewrite(table):
            return match.group(0)
        rewritten = rewrite_target(table)
        if rewritten is None:
            return match.group(0)
        return f"{prefix}{rewritten}"

    _TABLE_TAIL = r"(?=[\s,\)]|$|\s+AS\b)"
    _NOT_SUBQUERY = r"(?!\s*\()"

    from_pattern = re.compile(
        rf"(\bFROM\s+)(`?[\w]+`?){_TABLE_TAIL}{_NOT_SUBQUERY}",
        re.IGNORECASE,
    )
    sql = from_pattern.sub(replace_table_ref, sql)

    join_pattern = re.compile(
        rf"(\b(?:JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|INNER\s+JOIN|"
        rf"FULL\s+JOIN|CROSS\s+JOIN)\s+)(`?[\w]+`?){_TABLE_TAIL}{_NOT_SUBQUERY}",
        re.IGNORECASE,
    )
    sql = join_pattern.sub(replace_table_ref, sql)

    table_pattern = re.compile(r"(\bTABLE\s+)(`?[\w]+`?)\b", re.IGNORECASE)
    return table_pattern.sub(replace_table_ref, sql)
