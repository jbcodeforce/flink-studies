from pathlib import Path
import sqlite3
from typing import Optional
from agno.vectordb.chroma import ChromaDb
from agno.vectordb.search import SearchType
from agno.knowledge.embedder.ollama import OllamaEmbedder
from km_agno.config import get_vstore_path, get_collection_name, get_contents_db_path, get_llm_model
from agno.db.sqlite.sqlite import SqliteDb  
from agno.knowledge.knowledge import Knowledge
from agno.models.ollama import Ollama
from agno.agent import Agent
"""
Set of utilities functions for content management,
"""

KNOWLEDGE_NAME = "Flink studies repo"

def list_md_filenames(folder: Path) -> list[str]:
    """
    Walk ``folder`` recursively and return each ``.md`` file's basename.

    Order is sorted by basename for stable output.
    """
    root = (folder / "docs").resolve()
    l = root.rglob("*.md")
    return sorted([p for p in l if p.is_file()])


def get_candidate_files(folder: Path) -> list[str]:
    """
    Back-compat alias for :func:`list_md_filenames`.
    """
    l=list_md_filenames(folder)
    return l


def get_vector_db() -> ChromaDb:
    return ChromaDb(
        collection=get_collection_name(),
        path=get_vstore_path(),
        persistent_client=True,
        search_type=SearchType.hybrid,
        embedder=OllamaEmbedder(id="nomic-embed-text", dimensions=768),
    )

def get_contents_db() -> SqliteDb:
    return SqliteDb(db_file=get_contents_db_path())

def get_table_names() -> list[str]:
    db_path = str(get_contents_db_path().resolve())
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        table_rows = conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%%' "
            "ORDER BY name"
        ).fetchall()
        table_names = [r["name"] for r in table_rows]
        return table_names

def get_table_column_names(table_name: str) -> list[str]:
    db_path = str(get_contents_db_path().resolve())
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        column_rows = conn.execute(
            f"PRAGMA table_info('{table_name}')"
        ).fetchall()
        column_names = [r["name"] for r in column_rows]
        return column_names

def get_table_sample(table_name: str, limit:int=3) -> list[dict]:
    db_path = str(get_contents_db_path().resolve())
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        sample = conn.execute(
            f"SELECT * FROM '{table_name}' LIMIT {limit}"
        ).fetchall()
        return sample


def get_expert_knowledge(contents_db: Optional[SqliteDb] = None) -> Knowledge:
    """Build Knowledge for the expert agent. Pass ``contents_db`` to share one SqliteDb with ``Agent(db=...)``."""
    db = contents_db if contents_db is not None else get_contents_db()
    return Knowledge(
        name=KNOWLEDGE_NAME,
        description="Indexed flink-studies documentation and code",
        vector_db=get_vector_db(),
        contents_db=db,
        max_results=5,
    )


instructions = """\
You are an expert on the Apache Flink framework and building AI event-driven agents.

## Workflow

1. Search
   - For questions about Flink, always search your knowledge base first
   - Extract key concepts from the query to search effectively

2. Synthesize
   - Combine information from multiple search results
   - Prioritize official documentation over general knowledge

3. Present
   - Lead with a direct answer
   - Include code examples when helpful
   - Keep it practical and actionable

## Rules

- Always search knowledge before answering questions
- If the answer isn't in the knowledge base, say so
- Include code snippets for implementation questions
- Be concise — developers want answers, not essays\
"""

def get_expert_agent() -> Agent:
    return Agent(
                    name="Expert Agent",
                    model=Ollama(id=get_llm_model()),
                    db=get_contents_db(),
                    markdown=True,
                    knowledge=get_expert_knowledge(),
                    instructions=instructions,
                    search_knowledge=True,
                )
