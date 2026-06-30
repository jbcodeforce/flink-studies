# Python producer patterns

Scaffolded demos use **`code/flink-sql/cm_py_lib/kafka_json_producer.py`** via
`python/producers/produce_messages.py` (same pattern as
[`13-materialized-table/rides_producer.py`](../../../code/flink-sql/13-materialized-table/rides_producer.py)).

## Quick start

```bash
cd e2e-demos/<demo>/python
uv sync
uv run producers/produce_messages.py --count 10
```

The producer locates `cm_py_lib` by walking up to the flink-studies repo root (no copy).

## Dependencies

- `KafkaJSONProducer` — topic creation, Schema Registry JSON, Pydantic validation
- Pydantic model in `produce_messages.py` — align fields with `cccloud/ddl.<entity>.sql`

## Environment variables

From [`cm_py_lib/kafka_json_producer.py`](../../../code/flink-sql/cm_py_lib/kafka_json_producer.py):

**Kafka**

| Variable | Purpose |
|----------|---------|
| `KAFKA_BOOTSTRAP_SERVERS` | Broker list (default `localhost:9094`) |
| `KAFKA_TOPIC` | Topic (scaffold default: primary topic) |
| `KAFKA_API_KEY` / `KAFKA_API_SECRET` | Confluent Cloud SASL |
| `KAFKA_SECURITY_PROTOCOL` | e.g. `SASL_SSL` (auto when API key set) |

**Schema Registry**

| Variable | Purpose |
|----------|---------|
| `SCHEMA_REGISTRY_ENDPOINT` | Registry URL |
| `SCHEMA_REGISTRY_API_KEY` / `SCHEMA_REGISTRY_API_SECRET` | Basic auth |

Load CC credentials: `source code/flink-sql/set_env.sh` or `python/.env`.

## Local Docker without Schema Registry

```bash
uv run producers/produce_messages.py --count 5 --no-schema-registry
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
```

## Customize

1. Extend the Pydantic model to match your DDL columns
2. Replace `generate_record()` with domain-specific data (see `rides_producer.py`)
3. Add `--schema` variants for evolution demos if needed

## CC + json-registry Flink tables

Keep `use_schema_registry=True` (default) so payloads match `'value.format' = 'json-registry'`
in cccloud SQL.
