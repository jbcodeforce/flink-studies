# Knowledge Management with Agno

Index the flink-studies documentation and code with [Agno](https://docs.agno.com) and a local [Chroma](https://www.trychroma.com/) store, then run semantic **search** (vector retrieval) or **ask** (RAG: local [Ollama](https://ollama.com) by default, or other LLM with OpenAI client).

## Features

* [ ] List content of a folder passed as parameter to extract md file or code.
* [ ] 

## Setup

1. **Python 3.12+** and [uv](https://docs.astral.sh/uv/).

2. From this directory:

   ```bash
   cd assistants/km-agno
   uv sync
   ```

3. **Embeddings (index + search)**: `OPENAI_API_KEY` is required for OpenAI embeddings unless you change the embedder in code. Put keys in `assistants/.env` if you use it; km-agno loads that file when present.

4. **Chat (`ask`)**: by default uses **Ollama** on `OLLAMA_HOST` (see below). No OpenAI key needed for `ask` unless you set `KM_AGNO_LLM=openai`.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OPENAI_API_KEY` | — | Required for **index** and **search** (embeddings) |
| `OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama API base URL for local inference (`ask`) |
| `OLLAMA_BASE_URL` | — | Alias for `OLLAMA_HOST` if set |
| `OLLAMA_MODEL` | `llama3.1` | Model name as known to Ollama (`ollama pull …`) |
| `KM_AGNO_LLM` | `ollama` | `ollama` = local chat; `openai` = cloud chat (`OPENAI_API_KEY` + `OPENAI_MODEL` / `LLM_MODEL`) |
| `OPENAI_MODEL` | — | Overrides `LLM_MODEL` for OpenAI chat when `KM_AGNO_LLM=openai` |
| `LLM_MODEL` | `gpt-4o-mini` | OpenAI model id if using OpenAI for `ask` |
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

**Ask** (RAG; uses Ollama at `OLLAMA_HOST` by default):

```bash
# Ensure Ollama is running and the model is pulled, e.g. ollama pull llama3.1
uv run km-agno ask "Where is the agentic Flink demo described?"
```

**Search** (top similar chunks, no LLM answer; still needs `OPENAI_API_KEY` for query embedding):

```bash
uv run km-agno search "Flink SQL windowing" -k 8
```

## What gets indexed

Text-like files under the chosen root: Markdown, SQL, Java/Kotlin, Python, YAML, JSON (except common lockfiles), Terraform, shell, and more. Skipped: `.git`, `node_modules`, `__pycache__`, `.venv`, `target`, build outputs, lockfiles such as `package-lock.json` / `uv.lock`, files larger than 2 MiB, and secret-like patterns (e.g. `.env`, `.pem`).

## Notes

- Point `--root` at a smaller path (e.g. `docs/`) to test before indexing the full tree.
- The vector database is stored under `.data/chromadb` (see `.gitignore`); it is not committed to git.
- Remote Ollama: set `OLLAMA_HOST` to your server URL (must be reachable from this machine).
