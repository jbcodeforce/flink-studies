# Car Rides

Analytics data products for car ride operations (driver KPIs, customer churn indicators, revenue dashboards). Includes Python producer for CSV->Kafka and Metabase dashboard instructions.

## Business domain

ride-sharing

## Kafka topics

`raw_rides`, `driver_registry`, `customer_signups`

## Deployment targets

| Target | Path | Status |
|--------|------|--------|
| cccloud | `cccloud/` | Scaffold — customize |
| oss-flink | `oss-flink/` | Scaffold — customize |
| cp-flink | `cp-flink/` | Scaffold — customize |

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
uv run jump-start validate --path ../../../e2e-demos/car-rides
```

## What to customize

1. Refine DDL schemas and DML pipeline logic for your use case
2. Add test data under `python/producers/`
3. Document expected query results in deployment README files
