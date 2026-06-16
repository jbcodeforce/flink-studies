---
title: "Local expert chat (Agno)"
source: flink-studies/docs/assistants/local-expert-chat.md
ingested:
tags: [flink, assistants]
type: article
compiled: false
---
# Local expert chat (Agno)

This site is built with MkDocs and deployed to GitHub Pages. The **indexed Flink expert chat** is a separate application that runs **only on your machine**. It is not part of the static site and is not available on the published documentation URL.

!!! warning "GitHub Pages"

    Links like [http://localhost:8000](http://localhost:8000) work only when you have started the chat stack locally. Visitors browsing the published docs see this page as setup instructions, not a live chat.

## What it does

The [km-agent](https://github.com/jbcodeforce/km-agent) assistant compiles documentation into a wiki, embeds wiki content into pgvector for semantic search, and exposes an **AgentOS** HTTP API plus a **Vue** chat UI. Chat runs through the **kma team** leader (`POST /teams/kma/runs`), which coordinates Navigator, Researcher, Compiler, and Linter.

For research or news requests, the team ingests sources to `raw/`, answers immediately, then compiles and lints the wiki in the background. Set `KMA_PARALLEL_API_KEY` (Researcher) and `KMA_AUTO_COMPILE_AFTER_RESEARCH=1` in `assistants/km-agent/.env` to enable the full enrichment pipeline.

## Prerequisites

- Docker Desktop
- OMLX on this Mac or on a remote host (**chat only** — `KMA_LLM_BASE_URL` in `assistants/km-agent/.env`)
- Embeddings run **inside the container** via fastembed (`KMA_EMBED_PROVIDER=fastembed`) — no OMLX embed server
- No km-agent repository clone — flink-studies pulls the published image `jbcodeforce/km-agent:latest` (must include fastembed + `index_wiki.py`)

## Quick start

1. Copy and edit environment:

   ```bash
   cp assistants/km-agent/.env.example assistants/km-agent/.env
   ```

   Set `KMA_LLM_BASE_URL` to your OMLX server (same Mac: `http://host.docker.internal:7999/v1`, remote: `http://<host>:7999/v1`). Leave `KMA_EMBED_PROVIDER=fastembed` unless you intentionally use OMLX for embeddings.

2. Start OMLX on the host that runs the **chat** model.

3. From the flink-studies repository root:

   ```bash
   ./assistants/start_km_agent.sh
   ```

After the stack is up you get:

| Service | URL | Purpose |
|--------|-----|---------|
| MkDocs | [http://localhost:8003](http://localhost:8003) | This documentation |
| Expert chat UI | [http://localhost:8000](http://localhost:8000) | Browser chat (UI served by the km-agent container) |
| AgentOS API | [http://localhost:8000/docs](http://localhost:8000/docs) | HTTP API |

## Prepare knowledge (compile + embed)

Two phases:

1. **Compile** — build `context/wiki/` from flink-studies docs (LLM via OMLX). See the km-agent [compile workflow](https://github.com/jbcodeforce/km-agent/blob/main/docs/USER_GUIDE.md) (`compile_docs_folder.py` with `--context` pointing at `assistants/km-agent/context`).

2. **Embed wiki offline** — load wiki markdown into pgvector for the Navigator `search_wiki` tool (no LLM):

   ```bash
   ./assistants/index_wiki.sh
   ```

   Context persists under `assistants/km-agent/context/` (bind-mounted into the container).

3. **Re-embed after wiki changes** — after background compile or manual compile, refresh semantic search:

   ```bash
   ./assistants/index_wiki.sh
   ```

### Index-first vs embeddings

Wiki retrieval has two modes:

- **Index-first (default):** Navigator reads `wiki/index.md` (article catalog with one-line summaries) and pulls full articles via `read_file`. No embed step required after compile.
- **Semantic search (optional):** `index_wiki.sh` embeds chunks into pgvector for the `search_wiki` tool. Use when the wiki outgrows a single index read or queries do not match index wording.

`.state.json` tracks compile/lint timestamps and counts — it is not an article index. See [km-agent wiki RAG architecture](https://github.com/jbcodeforce/km-agent/blob/main/docs/ARCHITECTURE_WIKI_RAG.md) for how Knowledge, Learnings, and Wiki differ.

## Stop the stack

```bash
./assistants/start_km_agent.sh --down
```

Or set `KMA_STOP_DOCKER_ON_EXIT=1` in `.env` to stop containers when the start script exits.
