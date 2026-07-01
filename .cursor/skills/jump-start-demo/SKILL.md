---
name: jump-start-demo
description: Scaffolds foundational Flink e2e demo code for flink-studies — Confluent Cloud SQL, local Docker, deploy manifests, and Python producers. Use when creating a new e2e demo, jump-starting a streaming demo, or scaffolding flink-studies demo foundations.
---

# Jump Start Demo (Cursor)

Canonical skill document: [assistants/jump_start_demo/SKILL.md](../../assistants/jump_start_demo/SKILL.md)

Read and follow that file for the full workflow, critical Flink SQL rules, validation checklist, and tool usage.

## Quick commands

```bash
cd assistants/jump_start_demo/tools && uv sync
uv run jump-start init --name <slug> --domain <domain> --topics <t1,t2> --targets cccloud,oss-flink \
  --output ../../../e2e-demos/<slug>
uv run jump-start validate --path ../../../e2e-demos/<slug>
uv run jump-start manifest --path ../../../e2e-demos/<slug>/cccloud
```

Agno agent: `cd assistants/jump_start_demo/agent && uv sync && uv run jump-start-agent`
