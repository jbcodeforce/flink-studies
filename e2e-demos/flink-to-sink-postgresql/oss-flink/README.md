# Flink to PostgreSQL sink – OSS / Docker Compose

## Goal

Join two Kafka topics (e.g. orders + shipments) with Flink, write to output topic, sink to PostgreSQL via Kafka JDBC connector. Run with Docker Compose (OSS Flink, Kafka, Connect, PostgreSQL).

## Status

Ready. Docker Compose at root; optional [../k8s/](../k8s/) for K8s.

## Implementation approach

- **No Terraform.** [../docker-compose.yaml](../docker-compose.yaml) for full stack.
- **Application logic:** Flink DML and connector config at root.

## How to run

From **demo root**: `docker compose up`, create topics and connector (see root README), send data, run Flink SQL, verify in PostgreSQL. See [../README.md](../README.md).
