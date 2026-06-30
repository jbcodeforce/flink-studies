# Jump Start Demo

Scaffold foundational code for new Flink e2e demos. Supports Confluent Cloud (`cccloud/`) and local Docker (`oss-flink/`) deployment layouts.

## Quick start (no LLM)

From the repository root:

```bash
cd assistants/jump_start_demo/tools
uv sync

uv run jump-start init \
  --name order-tracking \
  --domain retail \
  --targets cccloud,oss-flink \
  --topics orders,inventory-updates \
  --output ../../../e2e-demos/order-tracking

uv run jump-start validate --path ../../../e2e-demos/order-tracking
uv run jump-start manifest --path ../../../e2e-demos/order-tracking/cccloud
```

Or use shell wrappers:

```bash
./assistants/jump_start_demo/scripts/init_demo.sh init --name order-tracking ...
```

## Agno agent

```bash
cd assistants/jump_start_demo/agent
uv sync
uv run jump-start-agent
```

Requires oMLX (default) or set `JUMP_START_LLM_PROVIDER=openai` and related env vars.

## Agent skills

| Location | Use |
|----------|-----|
| [SKILL.md](SKILL.md) | Canonical skill (Claude Code, portable) |
| [.cursor/skills/jump-start-demo/SKILL.md](../../.cursor/skills/jump-start-demo/SKILL.md) | Cursor project skill (if present locally) |

## Layout

```
assistants/jump_start_demo/
├── SKILL.md           # Agent workflow and rules
├── reference/         # Deep reference (Flink SQL, manifest, Docker)
├── templates/         # File templates for scaffold
├── tools/             # Deterministic CLI (jump-start)
├── agent/             # Local Agno agent
└── scripts/           # Shell wrappers
```

Generated demos land under `e2e-demos/<demo-name>/`. See [.cursor/skills/e2e-demo-structure/SKILL.md](../../.cursor/skills/e2e-demo-structure/SKILL.md) for layout rules.
