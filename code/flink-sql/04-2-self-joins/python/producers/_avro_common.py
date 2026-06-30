"""Shared helpers for self-joins Avro producers."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def flink_sql_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        lib = parent / "code" / "flink-sql" / "cm_py_lib" / "kafka_avro_producer.py"
        if lib.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib. Run from the flink-studies repo."
    )


def setup_cm_py_lib() -> Path:
    root = flink_sql_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    return root


def schemas_dir() -> Path:
    return Path(__file__).resolve().parents[1] / "schemas"


def ts_millis(iso_or_dt: str | datetime | None = None) -> int:
    if iso_or_dt is None:
        dt = datetime.now(timezone.utc)
    elif isinstance(iso_or_dt, datetime):
        dt = iso_or_dt.astimezone(timezone.utc)
    else:
        dt = datetime.fromisoformat(iso_or_dt.replace("Z", "+00:00"))
    return int(dt.timestamp() * 1000)


def detail_json(payload: dict) -> str:
    return json.dumps(payload, separators=(",", ":"))
