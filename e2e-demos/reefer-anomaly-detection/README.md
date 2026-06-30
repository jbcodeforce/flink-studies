# Reefer Anomaly Detection

iot streaming demo: reefer-anomaly-detection

## Business domain

iot

## Kafka topics

`reefer-sensors`

## Deployment targets

| Target | Path | Status |
|--------|------|--------|
| oss-flink | `oss-flink/` | Scaffold — customize |

## Prerequisites

- For **cccloud/**: Confluent Cloud credentials in `~/.confluent/.env` (see [code/flink-sql/tools/README.md](../../../code/flink-sql/tools/README.md))
- For **oss-flink/**: Docker Compose v2
- Python 3.11+ and [uv](https://github.com/astral-sh/uv) for producers under `python/`

## Quick start

Scaffolded by [assistants/jump_start_demo](../../assistants/jump_start_demo/). Customize SQL, then deploy:

```bash
# Confluent Cloud
cd cccloud && make sync && make deploy-ddl && make deploy-pipeline

# Local Docker
cd oss-flink && docker compose up -d && ./scripts/run_demo.sh
```

## Validation

```bash
cd assistants/jump_start_demo/tools && uv sync
uv run jump-start validate --path ../../../e2e-demos/reefer-anomaly-detection
```

## What to customize

1. Refine DDL schemas and DML pipeline logic for your use case
2. Add test data under `python/producers/`
3. Document expected query results in deployment README files
