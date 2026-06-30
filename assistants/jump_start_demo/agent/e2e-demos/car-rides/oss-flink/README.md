# Car Rides — Local Docker (OSS Flink)

## Goal

Run car-rides locally with Kafka and Flink via Docker Compose.

## Status

Scaffold — compose brings up Kafka + Flink; customize SQL under `sql/` when added.

## Prerequisites

- Docker Compose v2

## How to run

```bash
docker compose up -d --build
./scripts/run_demo.sh
```

Kafka topic (auto-created): `raw_rides`

## Troubleshooting

See [assistants/jump_start_demo/reference/local-docker.md](../../../assistants/jump_start_demo/reference/local-docker.md).
