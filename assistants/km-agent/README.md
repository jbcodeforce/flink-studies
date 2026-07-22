# km-agent for flink

Studies-hosted km-agent layout. AgentOS and the chat UI run from the km-agent clone; context and configuration live here.

## Prerequisites

- km-agent clone at path recorded in `.kma-home`
- macOS 26+ with Apple `container` CLI (Postgres)
- `uv`, `npm`, OMLX (or configured cloud LLM)
- `docs/` with km-agent raw frontmatter (see `docs/.manifest.json`)

## Quick start

```bash
# 1. Copy and edit secrets (if not already done)
cp example.env .env
# edit .env — LLM keys, ports

# 2. Start stack (Postgres + AgentOS + chat UI)
./starter_mac.sh --dev --frontend

# 3. Verify
./verify_config.sh --frontend

# 4. Ensure raw frontmatter, then compile docs into context/wiki/
./add_raw_frontmatter.sh --check
./compile_docs_folder.sh
```

## Wrapper scripts

| Script | Purpose |
|--------|---------|
| `starter_mac.sh` | Start Postgres + AgentOS (+ frontend) |
| `verify_config.sh` | Check env, DB, LLM, UI |
| `add_raw_frontmatter.sh` | Add km-agent frontmatter to `docs/` |
| `compile_docs_folder.sh` | Compile `docs/` into `context/wiki/` |
| `index_wiki.sh` | Embed wiki markdown into pgvector |
| `index_studies_code.sh` | Catalog `code/`/`src/` into wiki concepts |
| `build_ontology.sh` | Rebuild `context/ontology/` from wiki |
| `run_search.sh` | Research query → ingest → compile → lint |

All wrappers load `.env` and delegate into the km-agent clone. Extra CLI flags are forwarded (`"$@"`).

## Layout

| Path | Purpose |
|------|---------|
| `context/raw/` | Researcher-ingested sources |
| `context/wiki/` | Compiled wiki (index, concepts, summaries) |
| `context/ontology/` | Derived RDF graph |
| `.env` | Runtime configuration (gitignored) |
| `.kma-home` | Absolute path to km-agent clone |

## Docs

- [km-agent USER_GUIDE](/Users/jerome/Documents/Code/km-agent/docs/USER_GUIDE.md)
- UC-2 compile workflow in USER_GUIDE
