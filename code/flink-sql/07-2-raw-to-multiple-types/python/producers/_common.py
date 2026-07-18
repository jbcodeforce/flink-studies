"""Shared helpers for raw-to-multiple-types JSON producer."""

from __future__ import annotations

import sys
from pathlib import Path


def flink_sql_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        lib = parent / "code" / "flink-sql" / "cm_py_lib" / "kafka_json_producer.py"
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
