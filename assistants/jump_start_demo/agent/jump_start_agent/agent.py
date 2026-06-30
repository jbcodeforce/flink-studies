"""Build the jump-start Agno agent."""

from __future__ import annotations

import os
from pathlib import Path

from agno.agent import Agent
from agno.db.sqlite import SqliteDb
from agno.models.ollama import Ollama
from agno.models.openai import OpenAIChat

from jump_start_agent.instructions import INSTRUCTIONS
from jump_start_agent.tools.builder import build_agent_tools

_AGENT_ROOT = Path(__file__).resolve().parents[1]
_DB_FILE = _AGENT_ROOT / "data" / "jump_start_agent.db"


def build_model():
    provider = os.getenv("JUMP_START_LLM_PROVIDER", "openai").lower()
    if provider == "openai":
        model_id = os.getenv("JUMP_START_MODEL_ID", "uCode-8b-base-mlx-8bit")
        return OpenAIChat(id=model_id, 
                          base_url=os.getenv("JUMP_START_LLM_HOST", "http://10.0.0.148:7999/v1"),
                          api_key=os.getenv("JUMP_START_LLM_API_KEY", "local-key"))
    model_id = os.getenv("JUMP_START_MODEL_ID", "llama3.2")
    host = os.getenv("JUMP_START_LLM_HOST", "http://127.0.0.1:11434")
    return Ollama(id=model_id, base_url=host)


def build_jump_start_agent() -> Agent:
    _DB_FILE.parent.mkdir(parents=True, exist_ok=True)
    return Agent(
        id="jump-start",
        name="Jump Start Demo",
        role="Scaffold Flink e2e demo foundations for flink-studies",
        model=build_model(),
        instructions=INSTRUCTIONS,
        tools=build_agent_tools(),
        db=SqliteDb(db_file=str(_DB_FILE)),
        add_history_to_context=True,
        num_history_runs=5,
        markdown=True,
    )
