"""Build the Agno Agent for repository Q&A."""

from __future__ import annotations

import os

from agno.agent import Agent
from agno.knowledge.knowledge import Knowledge
from agno.models.openai import OpenAIChat
from agno.models.ollama import Ollama

from km_agno.config import (
    get_chat_model,
    get_chroma_path,
    get_collection_name,
    get_ollama_host,
    get_ollama_model,
    load_assistants_dotenv,
    use_ollama_for_chat,
)
from km_agno.vector_store import build_knowledge

INSTRUCTIONS = [
    "You are a knowledge assistant for the flink-studies Apache Flink learning repository.",
    "Answer only using the retrieved repository content. If the index does not contain the answer, say so.",
    "Cite file paths (as in metadata source_path) when you refer to code or documentation.",
    "Be concise and technical. Prefer exact locations over vague summaries.",
]


def get_agent() -> Agent:
    load_assistants_dotenv()
    chroma_path = get_chroma_path()
    collection = get_collection_name()
    knowledge, _ = build_knowledge(chroma_path, collection)
    if use_ollama_for_chat():
        model = Ollama(
            id=get_ollama_model(),
            host=get_ollama_host(),
        )
    else:
        if not os.environ.get("OPENAI_API_KEY"):
            raise ValueError("OPENAI_API_KEY is not set. Use Ollama (default) or set the key for OpenAI.")
        model = OpenAIChat(id=get_chat_model())
    return Agent(
        model=model,
        knowledge=knowledge,
        search_knowledge=True,
        instructions=INSTRUCTIONS,
    )


def get_knowledge_only() -> Knowledge:
    load_assistants_dotenv()
    knowledge, _ = build_knowledge(get_chroma_path(), get_collection_name())
    return knowledge
