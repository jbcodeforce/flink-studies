---
name: jump-start-demo
description: Scaffolds foundational Flink e2e demo code for flink-studies — Confluent Cloud SQL, local Docker, deploy manifests, and Python producers. Use when creating a new e2e demo, jump-starting a streaming demo, or scaffolding flink-studies demo foundations.
---

# Jump Start Demo Skill

Scaffold foundational code for new demos under `e2e-demos/`. Combines structured artifact generation with repo-specific conventions.

**Layout rules:** [.cursor/skills/e2e-demo-structure/SKILL.md](../../.cursor/skills/e2e-demo-structure/SKILL.md)

**Deep reference:** [assistants/jump_start_demo/reference/](reference/)

## When to use

- User asks for a new e2e demo, Flink streaming demo, or quick demo scaffold
- Starting fraud detection, IoT, orders, or similar use cases
- Need both Confluent Cloud and local Docker variants

## Critical requirements

### Confluent Cloud Flink SQL

Never use: `'connector' = 'kafka'`, `'topic' = ...`, `'bootstrap.servers' = ...`

Always use on every table:

```sql
'key.format' = 'json-registry',
'value.format' = 'json-registry',
'kafka.consumer.isolation-level' = 'read-uncommitted'
```

- Key/distribution column first in schema
- `DISTRIBUTED BY (key) INTO N BUCKETS` or `PRIMARY KEY (...) NOT ENFORCED`
- SQL file naming: `ddl.*.sql`, `dml.*.sql`, `dml.insert_*.sql`

See [reference/confluent-flink-sql.md](reference/confluent-flink-sql.md).

### Deploy manifest

Each `cccloud/` folder needs `deploy_manifest.json`. Generate via CLI — do not hand-author statement names.

### E2E demo layout

```
e2e-demos/<demo-name>/
├── README.md
├── cccloud/          # CC Flink SQL + Makefile + manifest
├── oss-flink/        # docker-compose + scripts
├── cp-flink/         # optional stub
└── python/           # shared producers
```

## Workflow

### Phase 1: Requirements

Gather:

1. Business problem and domain (finance, retail, IoT, etc.)
2. Key entities and Kafka topics
3. Deployment targets: `cccloud`, `oss-flink`, and/or `cp-flink`
4. Success criteria (validation queries, expected outputs)

Use [reference/use-case-templates.md](reference/use-case-templates.md) for common presets.

### Phase 2: Scaffold

**Prefer deterministic tools over hand-created folders.**

CLI:

```bash
cd assistants/jump_start_demo/tools && uv sync
uv run jump-start init \
  --name <slug> \
  --domain <domain> \
  --targets cccloud,oss-flink \
  --topics topic-a,topic-b \
  --output ../../../e2e-demos/<slug>
```

Agno agent: call `scaffold_demo` with the same parameters.

### Phase 3: Customize SQL and manifest

1. Edit `cccloud/ddl.*.sql` and `cccloud/dml.pipeline.sql` for business logic
2. Regenerate manifest:

```bash
uv run jump-start manifest --path ../../../e2e-demos/<slug>/cccloud
```

3. For local Docker, extend `oss-flink/` with SQL scripts if needed

### Phase 4: Validate and document

```bash
uv run jump-start validate --path ../../../e2e-demos/<slug>
```

Update README files with:

- Specific run steps
- Test queries (raw stream, aggregation, windowed, filtered)
- Expected results

## Artifact tree by target

### cccloud/

| File | Purpose |
|------|---------|
| `ddl.<entity>.sql` | Source/sink table definitions |
| `dml.pipeline.sql` | Continuous queries |
| `deploy_manifest.json` | CC deploy groups (generated) |
| `Makefile` | Delegates to `code/flink-sql/tools` |
| `README.md` | Goal, status, how to run |

### oss-flink/

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Kafka + Flink stack |
| `scripts/run_demo.sh` | Start and health-check |
| `README.md` | Local run instructions |

### python/

| File | Purpose |
|------|---------|
| `producers/produce_messages.py` | Sample producer via `cm_py_lib.KafkaJSONProducer` |
| `pyproject.toml` | uv deps (confluent-kafka, pydantic, jsonschema) |

## Tool usage

| Method | When |
|--------|------|
| **Agno agent** (`assistants/jump_start_demo/agent/`) | Interactive demo design with tool calls |
| **CLI** (`jump-start init/validate/manifest`) | Scriptable, no LLM |
| **Skill only** | Agent reads this file and runs CLI commands |

Shell wrappers: `assistants/jump_start_demo/scripts/init_demo.sh`, `validate_demo.sh`

## Validation checklist

- [ ] Root `README.md` with business goal and deployment links
- [ ] `cccloud/`: at least one `ddl.*.sql` with `key.format` and `DISTRIBUTED BY` or `PRIMARY KEY`
- [ ] `cccloud/`: `deploy_manifest.json` present
- [ ] `oss-flink/`: `docker-compose.yml` and `README.md`
- [ ] `python/producers/` stub present
- [ ] `jump-start validate` passes (warnings acceptable for WIP)
- [ ] Deployment README documents test queries

## Test query types (document in cccloud/README)

1. **Raw stream:** `SELECT * FROM <source> LIMIT 10;`
2. **Aggregated state:** `SELECT * FROM <sink> ORDER BY ... DESC;`
3. **Windowed:** TUMBLE/HOP over event time
4. **Filtered:** `WHERE` on business threshold

## Common pitfalls

| Pitfall | Fix |
|---------|-----|
| Hand-written manifest statement names | Run `jump-start manifest` |
| Missing `key.format` on CC tables | Add both key and value format |
| Wrong SQL file prefix | Use `ddl.`, `dml.`, `dml.insert_` |
| Demo outside `e2e-demos/` | Default output is `e2e-demos/<name>/` |
| Empty cp-flink folder | Only create when requested; stub README is enough |

## What this skill does NOT do (v1)

- Terraform / Confluent Cloud IaC
- Auto-deploy to live CC or Docker
- Full cp-flink K8s manifests

## Additional resources

- [confluent-flink-sql.md](reference/confluent-flink-sql.md) — CC SQL rules
- [deploy-manifest.md](reference/deploy-manifest.md) — manifest and deploy
- [local-docker.md](reference/local-docker.md) — Docker patterns
- [use-case-templates.md](reference/use-case-templates.md) — fraud, IoT, orders
- [producer-python.md](reference/producer-python.md) — producer patterns
- [code/flink-sql/tools/README.md](../../../code/flink-sql/tools/README.md) — CC deploy tooling
