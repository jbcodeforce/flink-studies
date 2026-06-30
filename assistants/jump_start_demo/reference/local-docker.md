# Local Docker patterns

For `oss-flink/` demos, use self-contained Docker Compose stacks.

## Reference demos

- [e2e-demos/flink-watermark/oss-flink](../../../e2e-demos/flink-watermark/) — full Kafka + custom Flink image example
- Scaffold template — minimal Kafka KRaft + stock Flink 2.0 image

## Shared deployment assets

Repo-wide Docker configs live under [deployment/docker/](../../../deployment/docker/):

- `docker-compose.yaml` — main local stack
- `kafka-docker-compose.yaml` — Kafka only
- `flink-oss-docker-compose.yaml` — OSS Flink variant

## Scaffold compose stack

Generated `oss-flink/docker-compose.yml` includes:

1. **broker** — Confluent cp-kafka 8.2 KRaft (single node)
2. **init-kafka** — creates demo topic
3. **jobmanager** / **taskmanager** — Flink 2.0

Host access:

- Kafka: `localhost:9092`
- Flink UI: `http://localhost:8081`

## Run workflow

```bash
cd e2e-demos/<demo>/oss-flink
docker compose up -d --build
./scripts/run_demo.sh
```

## Producers

Use `python/producers/` at demo root with:

```bash
cd python && uv sync && uv run producers/produce_messages.py
```

Set `KAFKA_BOOTSTRAP_SERVERS=localhost:9092` for local runs.

Producers use [`code/flink-sql/cm_py_lib/kafka_json_producer.py`](../../../code/flink-sql/cm_py_lib/kafka_json_producer.py) — see [producer-python.md](../producer-python.md).

## Customization

For production-like demos, add:

- Custom Flink Dockerfile with Kafka SQL connector JAR (see flink-watermark)
- `sql/` folder and `scripts/run_sql.sh`
- Health checks and wait scripts
