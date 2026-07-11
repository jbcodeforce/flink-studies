"""Temporarily write migration outputs for dbt compile validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class TempWriteState:
    model_path: Path
    schema_path: Path
    sources_path: Path | None
    model_existed: bool
    schema_existed: bool
    sources_existed: bool
    previous_model: str | None
    previous_schema: str | None
    previous_sources: str | None
    wrote_files: bool = False


def begin_temp_write(
    model_path: Path,
    schema_path: Path,
    model_sql: str,
    schema_yml: str,
    *,
    sources_path: Path | None = None,
    sources_yml: str | None = None,
) -> TempWriteState:
    state = TempWriteState(
        model_path=model_path,
        schema_path=schema_path,
        sources_path=sources_path,
        model_existed=model_path.exists(),
        schema_existed=schema_path.exists(),
        sources_existed=sources_path.exists() if sources_path else False,
        previous_model=(
            model_path.read_text(encoding="utf-8") if model_path.exists() else None
        ),
        previous_schema=(
            schema_path.read_text(encoding="utf-8") if schema_path.exists() else None
        ),
        previous_sources=(
            sources_path.read_text(encoding="utf-8")
            if sources_path and sources_path.exists()
            else None
        ),
    )
    model_path.parent.mkdir(parents=True, exist_ok=True)
    model_path.write_text(model_sql, encoding="utf-8")
    schema_path.write_text(schema_yml, encoding="utf-8")
    if sources_path is not None and sources_yml is not None:
        sources_path.parent.mkdir(parents=True, exist_ok=True)
        sources_path.write_text(sources_yml, encoding="utf-8")
    state.wrote_files = True
    return state


def restore_temp_write(state: TempWriteState) -> None:
    if not state.wrote_files:
        return

    if state.model_existed:
        assert state.previous_model is not None
        state.model_path.write_text(state.previous_model, encoding="utf-8")
    elif state.model_path.exists():
        state.model_path.unlink()

    if state.schema_existed:
        assert state.previous_schema is not None
        state.schema_path.write_text(state.previous_schema, encoding="utf-8")
    elif state.schema_path.exists():
        state.schema_path.unlink()

    if state.sources_path is not None:
        if state.sources_existed:
            assert state.previous_sources is not None
            state.sources_path.write_text(state.previous_sources, encoding="utf-8")
        elif state.sources_path.exists():
            state.sources_path.unlink()

    state.wrote_files = False
