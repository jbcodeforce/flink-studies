"""
Editable JSON manifest for Flink table cleanup (derived from Kafka topic inventory).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from cc_deploy.kafka_client import is_internal_topic

DEFAULT_MANIFEST_NAME = "drop_tables_manifest.json"
DEFAULT_STATEMENT_PREFIX = "cleanup-drop"


@dataclass(frozen=True)
class DropTableEntry:
    topic: str
    table: str
    drop: bool


def build_manifest_from_topics(
    topics: list[str],
    *,
    bootstrap_servers: str,
    database: str | None = None,
    statement_prefix: str = DEFAULT_STATEMENT_PREFIX,
) -> dict[str, Any]:
    """Build a drop manifest dict from Kafka topic names."""
    tables = [
        {
            "topic": topic,
            "table": topic,
            "drop": not is_internal_topic(topic),
        }
        for topic in topics
    ]
    return {
        "source": "kafka",
        "bootstrap_servers": bootstrap_servers,
        "database": database,
        "generated_at": datetime.now(UTC).isoformat(),
        "statement_prefix": statement_prefix,
        "tables": tables,
    }


def manifest_to_json(manifest: dict[str, Any]) -> str:
    return json.dumps(manifest, indent=2) + "\n"


def write_manifest(manifest: dict[str, Any], path: Path) -> Path:
    path.write_text(manifest_to_json(manifest), encoding="utf-8")
    return path


def _entries_from_tables_list(tables: list[Any]) -> list[DropTableEntry]:
    entries: list[DropTableEntry] = []
    for item in tables:
        if isinstance(item, str):
            entries.append(DropTableEntry(topic=item, table=item, drop=True))
        elif isinstance(item, dict):
            topic = item.get("topic") or item.get("table", "")
            table = item.get("table") or topic
            drop = bool(item.get("drop", True))
            if not table:
                raise ValueError(f"Invalid table entry (missing table/topic): {item!r}")
            entries.append(DropTableEntry(topic=topic or table, table=table, drop=drop))
        else:
            raise ValueError(f"Invalid table entry type: {item!r}")
    return entries


def load_manifest(path: Path) -> tuple[list[DropTableEntry], dict[str, Any]]:
    """
    Load drop manifest from JSON.

    Supports full ``tables`` objects or shorthand ``drop_tables`` string list.
    Returns (entries, raw manifest dict).
    """
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    if "tables" in data:
        entries = _entries_from_tables_list(data["tables"])
    elif "drop_tables" in data:
        entries = _entries_from_tables_list(data["drop_tables"])
    else:
        raise ValueError(
            f"Manifest {path} must contain 'tables' or 'drop_tables'"
        )
    return entries, data


def tables_to_drop(entries: list[DropTableEntry]) -> list[str]:
    """Return table names marked for drop, preserving manifest order."""
    return [entry.table for entry in entries if entry.drop]
