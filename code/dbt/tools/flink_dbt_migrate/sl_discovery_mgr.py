"""
Shift left releated functions to work on existing shift_left utils Flink SQL repository
"""
import json
import hashlib
from pathlib import Path
from dataclasses import dataclass, field
from flink_dbt_migrate.flink_sql_processor import (
    discover_ddl_path,
    is_values_insert,
    parse_dml,
    parse_values_dml,
)

@dataclass(frozen=True)
class TableEntry:
    """A single table discovered inside a shift_left pipeline folder."""

    table_name: str
    dml_path: Path
    ddl_path: Path
    dml_sha256: str
    relative_path: Path  # path from pipeline root to the table's parent dir
    # table_name → absolute DDL path for upstream tables, sourced from pipeline_definition.json
    upstream_ddl_map: dict[str, Path] = field(default_factory=dict)
    is_seed: bool = False


def _upstream_ddl_map_from_pipeline_def(
    table_dir: Path,
    pipelines_parent: Path,
) -> dict[str, Path]:
    """
    Read pipeline_definition.json
    returns {table_name: abs_ddl_path} for all parents from the pipeline_root folder
    """
    pipeline_def = table_dir / "pipeline_definition.json"
    if not pipeline_def.is_file():
        return {}
    try:
        data = json.loads(pipeline_def.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}

    ddl_map: dict[str, Path] = {}
    for parent in data.get("parents", []):
        name = parent.get("table_name", "")
        ddl_ref = parent.get("ddl_ref", "")
        if name and ddl_ref:
            abs_ddl = (pipelines_parent / ddl_ref).resolve()
            if abs_ddl.is_file():
                ddl_map[name] = abs_ddl
    return ddl_map

def _find_pipelines_parent(folder: Path) -> Path:
    """Walk up from *folder* to find the directory that contains a 'pipelines/' sub-tree.

    Falls back to *folder* itself if no such ancestor is found.
    """
    current = folder.resolve()
    for ancestor in [current, *current.parents]:
        if (ancestor / "pipelines").is_dir():
            return ancestor
    return current


def crawl_pipeline_folder(folder: Path) -> list[TableEntry]:
    """
    Recursively walk *folder* and return one TableEntry per discoverable table.

    A table is discoverable when:
    - a ``sql_scripts/`` subdirectory exists, AND
    - at least one ``dml.*.sql`` file is present, AND
    - a matching ``ddl.*.sql`` can be resolved via the standard discovery rules.

    Tables whose DDL cannot be found are skipped with a warning on stderr.
    Upstream DDL paths are resolved from ``pipeline_definition.json`` when present.
    """
    folder = folder.resolve()
    pipelines_parent = _find_pipelines_parent(folder)

    entries: list[TableEntry] = []
    for sql_scripts_dir in sorted(folder.rglob("sql-scripts")):
        if not sql_scripts_dir.is_dir():
            continue
        table_dir = sql_scripts_dir.parent
        upstream_ddl_map = _upstream_ddl_map_from_pipeline_def(table_dir, pipelines_parent)

        for dml_file in sorted(sql_scripts_dir.glob("dml.*.sql")):
            try:
                dml_text = dml_file.read_text(encoding="utf-8")
                is_seed = is_values_insert(dml_text)
                if is_seed:
                    target_table = parse_values_dml(dml_text, source_file=dml_file.name).target_table
                else:
                    target_table = parse_dml(dml_text, source_file=dml_file.name).target_table
                ddl_file_path = Path(
                    discover_ddl_path(str(dml_file), target_table)
                )
            except FileNotFoundError as exc:
                print(f"WARNING: skipping {dml_file.name} — {exc}")
                continue
            except ValueError as exc:
                print(f"WARNING: skipping {dml_file.name} — {exc}")
                continue

            sha256 = hashlib.sha256(dml_file.read_bytes()).hexdigest()
            # relative_path: from folder root to the table directory (parent of sql_scripts)
            relative_path = table_dir.relative_to(folder)
            entries.append(
                TableEntry(
                    table_name=target_table,
                    dml_path=dml_file,
                    ddl_path=ddl_file_path,
                    dml_sha256=sha256,
                    relative_path=relative_path,
                    upstream_ddl_map=upstream_ddl_map,
                    is_seed=is_seed,
                )
            )
    return entries