"""Shared Chroma + Knowledge construction."""

from __future__ import annotations

import os
from pathlib import Path

from agno.knowledge.embedder.openai import OpenAIEmbedder
from agno.knowledge.knowledge import Knowledge
from agno.vectordb.chroma import ChromaDb

from km_agno.config import get_embedding_model


def build_knowledge(
    chroma_path: Path,
    collection: str,
) -> tuple[Knowledge, ChromaDb]:
    """Create Knowledge with persistent Chroma and OpenAI embedder."""
    chroma_path = Path(chroma_path)
    api_key = os.environ.get("OPENAI_API_KEY")
    embedder = OpenAIEmbedder(
        id=get_embedding_model(),
        api_key=api_key,
    )
    vector_db = ChromaDb(
        collection=collection,
        path=str(chroma_path),
        persistent_client=True,
        embedder=embedder,
    )
    knowledge = Knowledge(
        name="Flink studies repo",
        description="Indexed flink-studies documentation and code",
        vector_db=vector_db,
    )
    return knowledge, vector_db


def chroma_recreate(vector_db: ChromaDb) -> None:
    if vector_db.exists():
        vector_db.drop()
    vector_db.create()
