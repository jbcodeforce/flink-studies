"""Paths and environment defaults for km-agno."""

from __future__ import annotations

import os
from pathlib import Path

# Project root: .../assistants/km-agno
_PROJECT_DIR = Path(__file__).resolve().parent.parent
# flink-studies repository root (assistants is one level down)
_DEFAULT_REPO_ROOT = _PROJECT_DIR.parent.parent


def get_repo_root() -> Path:
    env = os.environ.get("STUDIES_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    return _DEFAULT_REPO_ROOT


def get_vstore_path() -> Path:
    env = os.environ.get("KM_AGNO_VSTORE_PATH")
    if env:
        return Path(env).expanduser().resolve()
    return _PROJECT_DIR / ".data" / "chromadb"

def get_contents_db_path() -> Path:
    env = os.environ.get("KM_AGNO_CONTENTS_DB_PATH")
    if env:
        return Path(env).expanduser().resolve()
    return _PROJECT_DIR / ".data" / "agent.db"


def get_collection_name() -> str:
    env = os.environ.get("KM_AGNO_COLLECTION_NAME")
    if env:
        return env
    return "flink_studies"
    
def get_llm_model() -> str:
    """OpenAI chat model id when KM_AGNO_LLM=openai (see also OPENAI_MODEL)."""
    return os.environ.get("LLM_MODEL", "qwen36-agent:latest")


def get_LLM_url() -> str:
    """LLM HTTP API base URL (e.g. local server)."""
    return (
        os.environ.get("LLM_URL")
        or "http://127.0.0.1:11434"
    )


def load_assistants_dotenv() -> None:
    """Load assistants/.env when present (OPENAI_API_KEY, etc.)."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    assist = _DEFAULT_REPO_ROOT / "assistants" / ".env"
    if assist.is_file():
        load_dotenv(assist, override=False)
