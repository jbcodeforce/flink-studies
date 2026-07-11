"""Compare source Flink DML with dbt-compiled model SQL."""

from __future__ import annotations

import difflib
import re
from dataclasses import dataclass

from flink_dbt_migrate.parse_dml import DmlStatement


@dataclass(frozen=True)
class CompareResult:
    body_match: bool
    body_diff: str
    source_insert: str
    reconstructed_insert: str
    insert_match: bool


def strip_line_comments(sql: str) -> str:
    lines: list[str] = []
    for line in sql.splitlines():
        stripped = re.sub(r"--.*$", "", line)
        if stripped.strip():
            lines.append(stripped)
    return "\n".join(lines)


def normalize_sql(sql: str) -> str:
    sql = strip_line_comments(sql)
    sql = sql.strip().rstrip(";")
    sql = re.sub(r"\s+", " ", sql)
    sql = re.sub(r"\s*([(),])\s*", r"\1", sql)
    sql = sql.replace("!=", "<>")
    return sql.lower()


def apply_ref_aliases(sql: str, aliases: dict[str, str]) -> str:
    """Replace compiled relation names with original bare table names."""
    result = re.sub(
        r"\{\{\s*source\(\s*['\"][^'\"]+['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
        r"\1",
        sql,
        flags=re.IGNORECASE,
    )
    for compiled_name, source_name in sorted(aliases.items(), key=lambda item: -len(item[0])):
        patterns = [
            rf"`{re.escape(compiled_name)}`",
            rf"\b{re.escape(compiled_name)}\b",
        ]
        for pattern in patterns:
            result = re.sub(pattern, source_name, result, flags=re.IGNORECASE)
    return result


def build_source_insert(dml: DmlStatement) -> str:
    parts: list[str] = []
    if dml.leading_comments:
        parts.append(dml.leading_comments)
    parts.append(f"INSERT INTO {dml.target_table}")
    parts.append(dml.body)
    return "\n".join(parts)


def build_reconstructed_insert(target_table: str, body: str) -> str:
    return f"INSERT INTO {target_table}\n{body}"


def compare_migration(
    source_dml: DmlStatement,
    compiled_sql: str,
    ref_aliases: dict[str, str] | None = None,
) -> CompareResult:
    ref_aliases = ref_aliases or {}

    source_body = source_dml.body
    compiled_body = apply_ref_aliases(compiled_sql.strip(), ref_aliases)

    normalized_source = normalize_sql(source_body)
    normalized_compiled = normalize_sql(compiled_body)

    body_match = normalized_source == normalized_compiled
    body_diff = ""
    if not body_match:
        body_diff = "\n".join(
            difflib.unified_diff(
                normalized_source.splitlines(),
                normalized_compiled.splitlines(),
                fromfile="source",
                tofile="compiled (refs normalized)",
                lineterm="",
            )
        )

    source_insert = build_source_insert(source_dml)
    reconstructed_insert = build_reconstructed_insert(
        source_dml.target_table,
        compiled_body,
    )

    normalized_source_insert = normalize_sql(source_insert)
    normalized_reconstructed = normalize_sql(reconstructed_insert)
    insert_match = normalized_source_insert == normalized_reconstructed

    return CompareResult(
        body_match=body_match,
        body_diff=body_diff,
        source_insert=source_insert,
        reconstructed_insert=reconstructed_insert,
        insert_match=insert_match,
    )


def format_compare_report(result: CompareResult) -> str:
    lines: list[str] = []
    if result.body_match:
        line_count = result.reconstructed_insert.count("\n") + 1
        target = result.reconstructed_insert.splitlines()[0].removeprefix("INSERT INTO ").strip()
        lines.append("Validation passed: query body matches source DML")
        lines.append(f"Reconstructed INSERT INTO {target} ({line_count} lines)")
        lines.append("")
        lines.append(result.reconstructed_insert)
        return "\n".join(lines)

    lines.append("# Query body mismatch")
    if result.body_diff:
        lines.append(result.body_diff)
    lines.append("")
    lines.append("# Reconstructed INSERT (for inspection)")
    lines.append(result.reconstructed_insert)
    return "\n".join(lines)
