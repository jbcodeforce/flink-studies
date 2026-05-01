"""CLI: index, ask, search."""

from __future__ import annotations

import os
from pathlib import Path

import typer
from km_agno.content_processor import list_md_filenames, get_expert_knowledge
from agno.knowledge.reader.markdown_reader import MarkdownReader
from km_agno.content_processor import get_expert_agent


current_dir = Path(__file__).resolve().parent
repo_root = current_dir.parent.parent.parent

app = typer.Typer(help="Index and query the flink-studies repository with Agno, Ollama and Chroma.")


def _load_env() -> None:
    from km_agno.config import load_assistants_dotenv

    load_assistants_dotenv()


@app.command("index")
def index_cmd(
    root: Path | None = typer.Option(
        repo_root,
        "--root",
        help="Repository root to index (default: FLINK_STUDIES_ROOT or flink-studies next to helpers)",
    ),
    recreate: bool = typer.Option(
        False,
        "--recreate",
        help="Drop the Chroma collection and rebuild from scratch",
    ),
) -> None:
    """Index allowed documentation and code files into the local vector store."""
    _load_env()
    typer.echo("Indexing the flink-studies repository...")
    names=list_md_filenames(root)
    typer.echo(f"Found {len(names)} markdown files to index.")
    knowledge = get_expert_knowledge()
    for filename in names:
        source=str(filename.relative_to(root))
        knowledge.insert(name=source, 
                        path=filename,
                         metadata={"source": source}, 
                         skip_if_exists=not recreate, 
                         reader=MarkdownReader()
                       )
        typer.echo(f"Indexed {source}")
@app.command("ask")
def ask_cmd(
    question: list[str] = typer.Argument(..., help="Question about the repository"),
) -> None:
    """Answer a question using the indexed knowledge (RAG)."""
    _load_env() # Load the environment variables
    typer.echo("Asking a question using the indexed knowledge (RAG)...")
    agent = get_expert_agent()
    agent.print_response(question, markdown=True, stream=False)

@app.command("search")
def search_cmd(
    query: str = typer.Argument(..., help="Semantic search query"),
    k: int = typer.Option(5, "-k", help="Number of chunks to return"),
) -> None:
    """Retrieve top matching chunks (no LLM), from knowledge base."""

    typer.echo("Searching the indexed knowledge (no LLM)...")
    knowledge = get_expert_knowledge()
    results = knowledge.search(query=query, max_results=k)
    for result in results:
        typer.echo(f"Result: {result.content}")

if __name__ == "__main__":
    app()
