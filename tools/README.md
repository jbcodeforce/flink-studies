# A set of tools for managing content

## Project manager CLI

```sh
uv run demo_mgr_cli.py
```

## A Flink Researcher Agent

```sh
uv run flink_researcher.py
```

## Documentation Sync

Audit `docs/` for broken GitHub URL references, stale `mkdocs.yml` nav entries, and version string drift. Optionally auto-fix deterministic issues or delegate ambiguous ones to a local/remote LLM via Agno.

```sh
# Report only
uv run doc_sync.py audit

# Auto-fix deterministic issues (missing code/ prefix, version mismatches)
uv run doc_sync.py audit --fix

# LLM suggestions for issues that cannot be auto-fixed (local Ollama by default)
uv run doc_sync.py audit --agent

# Both
uv run doc_sync.py audit --fix --agent

# Use a remote model
uv run doc_sync.py audit --agent --model gpt-4o --base-url https://api.openai.com/v1

# Show canonical versions extracted from the repo
uv run doc_sync.py versions
```

See [`doc_sync.py`](doc_sync.py) for implementation details.
