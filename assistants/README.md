# Assistants

Set of Tools using LLM (local) to help maintain the content and code of this repository and run semantic search over its content.

## Local expert chat (km-agent)

The [km-agent](https://github.com/jbcodeforce/km-agent) stack runs from a **published Docker image**. You do not need to clone the km-agent repository. It is still possible to run the km-agent in dev mode with this repository / wiki as knowledge base.

### Prerequisites

- Docker or Mac container
- [OMLX](https://github.com/jundot/omlx) on this Mac **or** on another machine reachable from your computer. 
- MkDocs (for the local documentation site, started by default)

### Setup

```bash
cp assistants/km-agent/.env.example assistants/km-agent/.env
# Edit OMLX chat URL (KMA_LLM_BASE_URL) and model IDs
```

**Chat vs embeddings:** OMLX serves the LLM (`KMA_LLM_PROVIDER=mlx`). Embeddings run **in-process** in the container via fastembed (`KMA_EMBED_PROVIDER=fastembed`) — no OMLX embed model required.

Start OMLX separately for chat. The start script probes OMLX but does not start it.

### Start

From the repository root:

```bash
./assistants/start_km_agent.sh              # Docker stack + MkDocs on :8003
./assistants/start_km_agent.sh --no-mkdocs  # Docker stack only
./assistants/start_km_agent.sh --down       # stop containers
```

### Index wiki (offline, before chat)

After wiki markdown exists under `assistants/km-agent/context/wiki/`:

```bash
./assistants/index_wiki.sh              # embed into pgvector (kma_wiki)
./assistants/index_wiki.sh --dry-run    # list files only
./assistants/index_wiki.sh --recreate   # drop and rebuild vector index
```

Requires the stack to be running (`--no-mkdocs` is enough). No LLM call — Postgres + fastembed only.

| Service | URL |
|---------|-----|
| Expert chat UI | http://localhost:8000 |
| AgentOS API | http://localhost:8000/docs |
| MkDocs | http://localhost:8003 |

See [Local expert chat](../docs/assistants/local-expert-chat.md) for compile + index workflow.

## Jump Start Demo

Scaffold new e2e demos (Confluent Cloud SQL, local Docker, producers) with [jump_start_demo/](jump_start_demo/):

```bash
cd assistants/jump_start_demo/tools && uv sync
uv run jump-start init --name my-demo --domain retail --topics orders --targets cccloud,oss-flink
```

See [jump_start_demo/SKILL.md](jump_start_demo/SKILL.md) for the agent workflow.

## Other assistants

- `code_helper/` — code assistance utilities
- `flink_gtw_mcp/` — Flink SQL Gateway MCP server
- `streaming-discovery/` — streaming discovery specs
