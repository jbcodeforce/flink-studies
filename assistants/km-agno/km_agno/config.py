"""Paths and environment defaults for km-agno."""

from __future__ import annotations

import os
from pathlib import Path

# Project root: .../assistants/km-agno
_PROJECT_DIR = Path(__file__).resolve().parent.parent
# flink-studies repository root (assistants is one level down)
_DEFAULT_REPO_ROOT = _PROJECT_DIR.parent.parent


def get_repo_root() -> Path:
    env = os.environ.get("FLINK_STUDIES_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    return _DEFAULT_REPO_ROOT


def get_chroma_path() -> Path:
    env = os.environ.get("KM_AGNO_CHROMA_PATH")
    if env:
        return Path(env).expanduser().resolve()
    return _PROJECT_DIR / ".data" / "chromadb"


def get_collection_name() -> str:
    return os.environ.get("KM_AGNO_COLLECTION", "flink_studies")


def get_embedding_model() -> str:
    return os.environ.get("KM_AGNO_EMBEDDING_MODEL", "text-embedding-3-small")


def get_chat_model() -> str:
    return os.environ.get("OPENAI_MODEL", "gpt-4o-mini")


def load_assistants_dotenv() -> None:
    """Load assistants/.env when present (OPENAI_API_KEY, etc.)."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    assist = _DEFAULT_REPO_ROOT / "assistants" / ".env"
    if assist.is_file():
        load_dotenv(assist, override=False)
