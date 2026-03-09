# E2E streaming demo – OSS Flink (Docker Compose)

## Goal

Flink SQL demo: Kafka, MySQL, Elasticsearch, Kibana. User behavior (click, like, purchase, add to cart); TUMBLE windows, cumulative UV, top categories. See root [../README.md](../README.md).

## Status

Ready. Docker Compose at root.

## Implementation approach

- **No IaC.** [../docker-compose.yaml](../docker-compose.yaml) for Flink SQL, Kafka, MySQL, Elasticsearch, Kibana.
- **Application logic:** SQL and scripts at root.

## How to run

From **demo root**: `docker compose up`, run SQL client and DDL/DML from root README. See [../README.md](../README.md).
