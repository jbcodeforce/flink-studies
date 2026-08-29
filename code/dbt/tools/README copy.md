# A set of tools for managing content

## A Flink Researcher Agent

```sh
uv run flink_researcher.py
```

## Schema Registry → dbt YAML

`sr_to_dbt_yaml.py` fetches the key and/or value schema registered in
Confluent Schema Registry for a given Kafka topic and emits a ready-to-paste
dbt YAML block. Supports **JSON Schema** and **Avro** subjects.

### Required credentials

Set environment variables before running (or pass as CLI flags):

| Env var | CLI flag | Description |
|---|---|---|
| `SCHEMA_REGISTRY_URL` or `SCHEMA_REGISTRY_ENDPOINT` | `--sr-url` | Schema Registry base URL |
| `SCHEMA_REGISTRY_API_KEY` or `SCHEMA_REGISTRY_USER` | `--sr-key` | API key |
| `SCHEMA_REGISTRY_API_SECRET` or `SCHEMA_REGISTRY_PASSWORD` | `--sr-secret` | API secret |

```sh
export SCHEMA_REGISTRY_URL=https://psrc-xxx.us-east-2.aws.confluent.cloud
export SCHEMA_REGISTRY_API_KEY=YOUR_KEY
export SCHEMA_REGISTRY_API_SECRET=YOUR_SECRET
```

### Usage

```sh
# Value schema only — emit a sources: block (default)
uv run sr_to_dbt_yaml.py raw_hosts

# Both key and value schemas (prints two blocks)
uv run sr_to_dbt_yaml.py raw_hosts --subject-suffix key,value

# Emit a models: block for a staging model instead
uv run sr_to_dbt_yaml.py raw_hosts --output model --schema-name src_hosts

# Override the source/schema name in the output
uv run sr_to_dbt_yaml.py raw_listings --schema-name j9r-kafka

# Pass credentials explicitly (overrides env vars)
uv run sr_to_dbt_yaml.py raw_hosts \
    --sr-url https://psrc-xxx.us-east-2.aws.confluent.cloud \
    --sr-key ABCDEF \
    --sr-secret mysecret
```

### Output examples

**`--output sources`** (default) — paste into `models/sources.yaml`:

```yaml
sources:
- name: raw_hosts
  schema: raw_hosts
  tables:
  - name: raw_hosts
    columns:
    - name: host_id
      data_type: string
    - name: is_superhost
      data_type: boolean
  config:
    contract:
      enforced: true
```

**`--output model`** — paste into a model YAML file (e.g. `src_hosts_models.yml`):

```yaml
models:
- name: src_hosts
  config:
    contract:
      enforced: false
  columns:
  - name: host_id
    data_type: string
  - name: is_superhost
    data_type: boolean
```

### Reusable library

The schema-fetching and YAML-rendering logic lives in
`code/flink-sql/cm_py_lib/schema_registry.py` and can be imported directly
from any script in the repo:

```python
from cm_py_lib.schema_registry import SchemaFetcher, schema_to_columns, render_sources_yaml

fetcher = SchemaFetcher()                              # reads env vars
schema, schema_type = fetcher.fetch("raw_hosts-value")
columns = schema_to_columns(schema, schema_type)
print(render_sources_yaml("raw_hosts", "j9r-kafka", columns))
```
