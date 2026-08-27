"""Map Flink SQL column types to dbt schema.yml data_type values."""

from __future__ import annotations

import re

_SIMPLE_TYPES = {
    "STRING": "string",
    "INT": "int",
    "INTEGER": "int",
    "BIGINT": "bigint",
    "BOOLEAN": "boolean",
    "DATE": "date",
    "FLOAT": "float",
    "DOUBLE": "double",
    "BYTES": "bytes",
}

_TIMESTAMP_RE = re.compile(r"^TIMESTAMP\s*\(\s*(\d+)\s*\)$", re.IGNORECASE)
_DECIMAL_RE = re.compile(r"^DECIMAL\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)$", re.IGNORECASE)


def flink_type_to_dbt(flink_type: str) -> str:
    normalized = " ".join(flink_type.split())
    upper = normalized.upper()

    if upper in _SIMPLE_TYPES:
        return _SIMPLE_TYPES[upper]

    timestamp_match = _TIMESTAMP_RE.match(normalized)
    if timestamp_match:
        return f"timestamp({timestamp_match.group(1)})"

    decimal_match = _DECIMAL_RE.match(normalized)
    if decimal_match:
        return f"decimal({decimal_match.group(1)}, {decimal_match.group(2)})"

    return normalized.lower()
