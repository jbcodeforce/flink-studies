# Knowledge Management with Agno

Index the flink-studies documentation and code with [Agno](https://docs.agno.com) and a local [Chroma](https://www.trychroma.com/) store, then run semantic **search** (vector retrieval) or **ask** (RAG: local [Ollama](https://ollama.com) by default, or other LLM with OpenAI client).

## Features

* [ ] List content of a folder, passed as parameter, to extract md files or codes. This list of file will be processed one by one to build Agno knowledge based persisted in vector store and sqlite
* [x] Expose an agno_os server to be able to chat with the knowledge. -> server.py
* [x] Web chat UI (Vue 3 + Vite) under `frontend/` — AgentOS proxy, session list, URL query `session_id` / `user_id`
* [ ] CLI support to index the docs content

## Setup

1. **Python 3.12+** and [uv](https://docs.astral.sh/uv/).

2. From this directory:

   ```bash
   cd assistants/km_agno
   uv sync
   ```

## Indexing content using the CLI

### km_agno index

**Index** (first run or after large repo changes; can be slow and uses embedding API calls):

```bash
uv run km_agno index
# or a subtree while testing:
uv run km_agno index --root /path/to/flink-studies/docs
# full rebuild of the collection:
uv run km_agno index --recreate
```

**Ask** (RAG; uses Ollama at `OLLAMA_HOST` by default):

```bash
# Ensure Ollama is running and the model is pulled, e.g. ollama pull llama3.1
uv run km_agno ask "Where is the agentic Flink demo described?"
```

**Search** (top similar chunks, no LLM answer; still needs `OPENAI_API_KEY` for query embedding):

```bash
uv run km_agno search "Flink SQL windowing" -k 8
```

## What gets indexed

Text-like files under the chosen root: Markdown, SQL, Java/Kotlin, Python, YAML, JSON (except common lockfiles), Terraform, shell, and more. Skipped: `.git`, `node_modules`, `__pycache__`, `.venv`, `target`, build outputs, lockfiles such as `package-lock.json` / `uv.lock`, files larger than 2 MiB, and secret-like patterns (e.g. `.env`, `.pem`).


## Start the server

Only when th knowledge base is updated.

* Start with one of:
   ```sh
   uv run python -m km_agno.server
   # OR
   uv run fastapi dev km_agno/server.py
   # OR
   uv run uvicorn km_agno.server:app --reload --host 127.0.0.1 --port 7777
```

* The API doc is at [http://localhost:7777/docs](http://localhost:7777/docs)

* Get deployed agents:
   ```
   curl -X 'GET' 'http://localhost:7777/agents' -H 'accept: application/json'
   ```

* To post a query:

```sh
curl -X 'POST' 'http://localhost:7777/agents/expert-agent/runs' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'message=what are the key concepts of flink?' \
  -F 'stream=false' \
  -F 'session_id=session_2' \
  -F 'user_id=jerome'
```

## Web UI (chat)

The `frontend/` app is a small Vue 3 client that calls AgentOS through the Vite dev proxy (no CORS setup needed locally).

1. Start AgentOS on port **7777** (see [Start the server](#start-the-server)).
2. In another terminal:

   ```bash
   cd assistants/km_agno/frontend
   npm install
   npm run dev
   ```

3. Open the URL printed by Vite (default **http://localhost:5174**). API requests go to `/agent-os/*`, which proxies to `http://127.0.0.1:7777`.

**Environment (optional)**

| Variable | Purpose |
|----------|---------|
| `VITE_AGENT_OS_ORIGIN` | Proxy target if AgentOS is not on `127.0.0.1:7777` (also accepts `AGENT_OS_ORIGIN`) |
| `VITE_PORT` | Dev server port (default `5174`) |
| `VITE_STATIC_SITE_URL` | Optional URL for the top bar link back to your static docs site (e.g. MkDocs `http://127.0.0.1:8003`). If unset or empty, the button is hidden (good for a standalone chat repo). |
| `VITE_STATIC_SITE_LABEL` | Optional label for that link (default: `Back to studies`). |

Copy [`frontend/.env.example`](frontend/.env.example) to `frontend/.env` or `frontend/.env.local` and adjust. Exported variables in the shell are picked up by `npm run dev` as well (e.g. `export VITE_STATIC_SITE_URL=http://127.0.0.1:8003`).

**URL query parameters**

- `user_id`: Scoped sessions and runs; persisted in `localStorage` under `km_agno_user_id` when not present in the URL.
- `session_id`: Active conversation; updated after the first streamed `RunStarted` event when starting a new thread. Bookmark or share the URL to reopen the same session.

**Production build**

```bash
cd assistants/km_agno/frontend
npm run build
```

Serve `frontend/dist/` with any static host; you must configure that host to reverse-proxy `/agent-os` to your AgentOS origin, or set AgentOS CORS to allow the UI origin.

Set `VITE_STATIC_SITE_URL` (and optionally `VITE_STATIC_SITE_LABEL`) **before** `npm run build` if you want the top bar link in production builds; Vite inlines these at compile time.

**Tests**

```bash
cd assistants/km_agno/frontend
npm run test
```

### MkDocs integration

This repo’s documentation includes **Assistants → Local expert chat (Agno)** ([MkDocs page](../../docs/assistants/local-expert-chat.md)). From the repository root, `WITH_KM_AGNO_CHAT=1 ./start_local.sh` starts MkDocs (port 8003), AgentOS (7777), and the Vite UI (5174) together for local browsing and chat.

## Commands

## Notes

- Point `--root` at a smaller path (e.g. `docs/`) to test before indexing the full tree.
- The vector database is stored under `.data/chromadb` (see `.gitignore`); it is not committed to git.
- Remote Ollama: set `OLLAMA_HOST` to your server URL (must be reachable from this machine).
