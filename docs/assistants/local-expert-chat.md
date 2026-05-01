# Local expert chat (Agno)

This site is built with MkDocs and deployed to GitHub Pages. The **indexed Flink expert chat** is a separate application that runs **only on your machine**. It is not part of the static site and is not available on the published documentation URL.

!!! warning "GitHub Pages"

    Links like `http://localhost:5174` work only when you have started the chat stack locally. Visitors browsing the published docs see this page as setup instructions, not a live chat.

## What it does

The [km_agno](https://github.com/jbcodeforce/flink-studies/tree/main/assistants/km_agno) assistant indexes markdown and code under this repository (see the README there for scope), stores embeddings locally, and exposes an **AgentOS** HTTP API plus an optional **Vue** UI for semantic Q&A over your content.

## Quick start (three URLs)

After indexing and starting the stack you get:

| Service | URL | Purpose |
|--------|-----|---------|
| MkDocs | [http://localhost:8003](http://localhost:8003) | This documentation (when using `start_local.sh`) |
| Expert chat UI | [http://localhost:5174](http://localhost:5174) | Browser chat against AgentOS |
| AgentOS API | [http://localhost:7777/docs](http://localhost:7777/docs) | OpenAPI / health |

Use the nav entry **Assistants → Local expert chat** while running MkDocs locally to jump back here; open **Expert chat UI** in another tab when the frontend is running.

## Option A: Docs + chat together

From the repository root:

```bash
export WITH_KM_AGNO_CHAT=1
./start_local.sh
```

Prerequisites:

- Python **uv** env synced in `assistants/km_agno` (`uv sync`).
- Node dependencies in `assistants/km_agno/frontend` (`npm install` once).

This starts AgentOS on port **7777**, the Vite dev server on **5174**, then **MkDocs** on **8003**. Stop with Ctrl+C (child processes are torn down).

Unless you override it, **`start_local.sh` sets `VITE_STATIC_SITE_URL` to `http://localhost:8003`** for the chat UI so the top bar shows **Back to studies** (MkDocs). To hide that link: `VITE_STATIC_SITE_URL="" WITH_KM_AGNO_CHAT=1 ./start_local.sh`. For other repos or ports, set `VITE_STATIC_SITE_URL` and optionally `VITE_STATIC_SITE_LABEL` (see `assistants/km_agno/frontend/.env.example`).

## Option B: Manual terminals

1. Start AgentOS (from `assistants/km_agno`):

   ```bash
   uv run uvicorn km_agno.server:app --reload --host localhost --port 7777
   ```

2. Start the frontend (optional link back to MkDocs in the chat header):

   ```bash
   export VITE_STATIC_SITE_URL=http://localhost:8003
   cd assistants/km_agno/frontend && npm run dev
   ```

3. Start MkDocs (from repo root):

   ```bash
   mkdocs serve --dev-addr=localhost:8003
   ```

Full CLI flow (index, ask, search) is documented in [assistants/km_agno/README.md](https://github.com/jbcodeforce/flink-studies/tree/main/assistants/km_agno).

## Configuration reminders

- **Ollama** for the LLM: ensure the model from your env is pulled (see km_agno README).
- **Embeddings**: indexing uses your configured embedding provider; query/search may require API keys as documented there.
- The frontend proxies API calls to AgentOS via `/agent-os`; adjust `VITE_AGENT_OS_ORIGIN` only if AgentOS is not on `localhost:7777`.
