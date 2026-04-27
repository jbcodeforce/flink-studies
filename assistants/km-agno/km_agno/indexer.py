"""Walk the repository and insert documents into Agno Knowledge (Chroma)."""

from __future__ import annotations

import traceback
from collections.abc import Callable
from pathlib import Path

from agno.knowledge.chunking.recursive import RecursiveChunking
from agno.knowledge.knowledge import Knowledge
from agno.knowledge.reader.markdown_reader import MarkdownReader
from agno.knowledge.reader.text_reader import TextReader

from km_agno.config import get_chroma_path, get_collection_name, get_repo_root
from km_agno.ignore_rules import discover_files
from km_agno.vector_store import build_knowledge, chroma_recreate

MARKDOWN_EXTS: frozenset[str] = frozenset({".md", ".mdx"})


def _reader_for(path: Path) -> MarkdownReader | TextReader:
    ext = path.suffix.lower()
    if ext in MARKDOWN_EXTS:
        return MarkdownReader()
    return TextReader(
        chunking_strategy=RecursiveChunking(chunk_size=1200, overlap=100),
    )


def index_repo(
    repo_root: Path | None = None,
    *,
    recreate: bool = False,
    on_progress: Callable[[int, int, str], None] | None = None,
) -> tuple[Knowledge, int, int]:
    """
    Index all allowed files under repo_root.
    Returns (knowledge, ok_count, err_count).
    """
    from km_agno.config import load_assistants_dotenv

    load_assistants_dotenv()
    root = (repo_root or get_repo_root()).resolve()
    paths = discover_files(root)
    chroma_path = get_chroma_path()
    chroma_path.parent.mkdir(parents=True, exist_ok=True)
    collection = get_collection_name()

    knowledge, vector_db = build_knowledge(chroma_path, collection)
    if recreate:
        chroma_recreate(vector_db)
    else:
        vector_db.create()

    ok = 0
    err = 0
    for i, file_path in enumerate(paths):
        rel = file_path.resolve().relative_to(root)
        rel_s = str(rel).replace("\\", "/")
        if on_progress:
            on_progress(i + 1, len(paths), rel_s)
        reader = _reader_for(file_path)
        name = f"{rel_s}"
        try:
            knowledge.insert(
                name=name,
                path=str(file_path),
                reader=reader,
                metadata={"source_path": rel_s, "ext": file_path.suffix or ""},
            )
            ok += 1
        except Exception:
            err += 1
            traceback.print_exc()
    return knowledge, ok, err
