# km-agno

Index the flink-studies documentation and code with [Agno](https://docs.agno.com) and a local [Chroma](https://www.trychroma.com/) store, then run semantic **search** (vector retrieval) or **ask** (RAG with an OpenAI chat model).

## Setup

1. **Python 3.11+** and [uv](https://docs.astral.sh/uv/).

2. From this directory:

   ```bash
   cd assistants/km-agno
   uv sync
   ```

3. **API key**: set `OPENAI_API_KEY` (embeddings for indexing/search, and chat for `ask`). A common pattern in this repo is to put it in `assistants/.env`; km-agno loads that file automatically when it exists.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OPENAI_API_KEY` | (required for index/ask/search) | OpenAI API |
| `OPENAI_MODEL` | `gpt-4o-mini` | Chat model for `ask` |
| `FLINK_STUDIES_ROOT` | auto: parent of `assistants/` | Repository root when not passing `--root` |
| `KM_AGNO_CHROMA_PATH` | `assistants/km-agno/.data/chromadb` | Persistent Chroma directory |
| `KM_AGNO_COLLECTION` | `flink_studies` | Chroma collection name |
| `KM_AGNO_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding model id |

## Commands

**Index** (first run or after large repo changes; can be slow and uses embedding API calls):

```bash
uv run km-agno index
# or a subtree while testing:
uv run km-agno index --root /path/to/flink-studies/docs
# full rebuild of the collection:
uv run km-agno index --recreate
```

**Ask** (RAG: model answers using retrieved chunks):

```bash
uv run km-agno ask "Where is the agentic Flink demo described?"
```

**Search** (top similar chunks, no LLM answer):

```bash
uv run km-agno search "Flink SQL windowing" -k 8
```

## What gets indexed

Text-like files under the chosen root: Markdown, SQL, Java/Kotlin, Python, YAML, JSON (except common lockfiles), Terraform, shell, and more. Skipped: `.git`, `node_modules`, `__pycache__`, `.venv`, `target`, build outputs, lockfiles such as `package-lock.json` / `uv.lock`, files larger than 2 MiB, and secret-like patterns (e.g. `.env`, `.pem`).

## Notes

- Point `--root` at a smaller path (e.g. `docs/`) to test before indexing the full tree.
- The vector database is stored under `.data/chromadb` (see `.gitignore`); it is not committed to git.
