"""CLI: index, ask, search."""

from __future__ import annotations

import os
from pathlib import Path

import typer

app = typer.Typer(help="Index and query the flink-studies repository with Agno + Chroma.")


def _load_env() -> None:
    from km_agno.config import load_assistants_dotenv

    load_assistants_dotenv()


@app.command("index")
def index_cmd(
    root: Path | None = typer.Option(
        None,
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
    if not os.environ.get("OPENAI_API_KEY"):
        typer.secho("OPENAI_API_KEY is required (e.g. in assistants/.env).", err=True, fg="red")
        raise typer.Exit(1)

    from km_agno.config import get_repo_root, get_chroma_path, get_collection_name

    r = (root or get_repo_root()).resolve()
    if not r.is_dir():
        typer.secho(f"Not a directory: {r}", err=True, fg="red")
        raise typer.Exit(1)

    typer.echo(f"Repository root: {r}")
    typer.echo(f"Chroma path: {get_chroma_path()}")
    typer.echo(f"Collection: {get_collection_name()}")
    if recreate:
        typer.secho("Recreate: existing collection will be dropped.", fg="yellow")

    def on_progress(n: int, total: int, rel: str) -> None:
        if n == 1 or n % 50 == 0 or n == total:
            typer.echo(f"  [{n}/{total}] {rel}")

    from km_agno.indexer import index_repo

    _, ok, err = index_repo(r, recreate=recreate, on_progress=on_progress)
    typer.echo(f"Done. Indexed: {ok}, errors: {err}.")


@app.command("ask")
def ask_cmd(
    question: list[str] = typer.Argument(..., help="Question about the repository"),
) -> None:
    """Answer a question using the indexed knowledge (RAG)."""
    _load_env()
    from km_agno.config import use_ollama_for_chat

    if not use_ollama_for_chat() and not os.environ.get("OPENAI_API_KEY"):
        typer.secho(
            "OPENAI_API_KEY is required when KM_AGNO_LLM=openai.",
            err=True,
            fg="red",
        )
        raise typer.Exit(1)

    q = " ".join(question).strip()
    if not q:
        raise typer.Exit(0)

    from km_agno.agent_factory import get_agent

    agent = get_agent()
    agent.print_response(q, markdown=True, stream=False)


@app.command("search")
def search_cmd(
    query: str = typer.Argument(..., help="Semantic search query"),
    k: int = typer.Option(5, "-k", help="Number of chunks to return"),
) -> None:
    """Retrieve top matching chunks (no LLM), from the vector store."""
    _load_env()
    if not os.environ.get("OPENAI_API_KEY"):
        typer.secho("OPENAI_API_KEY is required for embedding the query.", err=True, fg="red")
        raise typer.Exit(1)

    from km_agno.agent_factory import get_knowledge_only

    knowledge = get_knowledge_only()
    vdb = knowledge.vector_db
    docs = vdb.search(query, limit=k)
    for i, doc in enumerate(docs, 1):
        meta = doc.meta_data or {}
        src = meta.get("name") or meta.get("source_path") or "?"
        typer.echo("---")
        typer.echo(f"#{i} {src}")
        text = (doc.content or "")[: 1200]
        typer.echo(text)
        if len(doc.content or "") > 1200:
            typer.echo("... [truncated]")


def main() -> None:
    app()


if __name__ == "__main__":
    main()
