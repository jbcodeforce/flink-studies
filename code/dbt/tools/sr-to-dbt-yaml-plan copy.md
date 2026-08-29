# Plan: Schema Registry → dbt YAML Generator

## Overview

Two things happen:

1. **`code/flink-sql/cm_py_lib/schema_registry.py`** — a new reusable module
   in the shared library that wraps `SchemaRegistryClient` (already used by
   `kafka_json_producer.py` and `kafka_avro_producer.py`) into a
   `SchemaFetcher` class, plus a pure `schema_to_columns` function and two
   YAML renderers. This code belongs in cm_py_lib so any script in the repo
   can import it.

2. **`tools/sr_to_dbt_yaml.py`** — a thin CLI entry point in the `tools/`
   uv project. It adds `sys.path` to pick up cm_py_lib (same pattern as
   `produce_to_kafka.py`) and calls the cm_py_lib functions. No logic lives
   here beyond argument parsing and wiring.

### Reuse from cm_py_lib

| Existing symbol | How it is reused |
|---|---|
| `SCHEMA_REGISTRY_URL` | SR endpoint env var already resolved |
| `SCHEMA_REGISTRY_USER` | SR key env var already resolved |
| `SCHEMA_REGISTRY_PASSWORD` | SR secret env var already resolved |
| `KafkaAvroProducer._create_schema_registry_client` | Pattern copied into `SchemaFetcher.__init__` |
| `KafkaAvroProducer._ensure_subject` → `get_latest_version` | Direct call in `SchemaFetcher.fetch` |

### Architecture

```
tools/sr_to_dbt_yaml.py          (CLI only — thin wrapper)
  └─ imports cm_py_lib.schema_registry
       ├── SchemaFetcher          (SR access, auth from env or args)
       ├── schema_to_columns()    (pure fn: schema dict → ColumnSpec list)
       ├── render_sources_yaml()  (pure fn → YAML string, sources block)
       └── render_model_yaml()    (pure fn → YAML string, models block)
```

---

## Sub-Tasks

### 1 — Add `confluent-kafka` to `tools/pyproject.toml`

**Intent**  
`tools/` currently has no `confluent-kafka` dependency. It is needed to
import `cm_py_lib` which imports `confluent_kafka` at the module level.

**Expected Outcomes**  
- `confluent-kafka >= 2.10.0` appears in `[project].dependencies`.
- `uv.lock` updated.

**Todo List**  
- [ ] Add `confluent-kafka >= 2.10.0` to `tools/pyproject.toml`.
- [ ] Run `uv add confluent-kafka` inside `tools/` to update the lockfile.

**Relevant Context**  
- [`tools/pyproject.toml`](tools/pyproject.toml)
- cm_py_lib already declares `confluent-kafka[schema-registry]>=2.3.0` in its
  module docstring; the `tools/` project needs an independent declaration.

**Status** `[ ] pending`

---

### 2 — Create `code/flink-sql/cm_py_lib/schema_registry.py`

**Intent**  
Place all SR-access, type-mapping, and YAML-rendering logic in the shared
library so it can be imported by any script (not just the CLI tool).

**Module structure** (clearly delimited sections inside one file):

```python
# ── Schema Registry access ────────────────────────────────────────────────
class SchemaFetcher:
    def __init__(self, url=None, key=None, secret=None): ...
    # Falls back to SCHEMA_REGISTRY_URL / _USER / _PASSWORD from
    # kafka_json_producer (already resolved from env at import time).
    # url/key/secret args override env for explicit CLI use.

    def fetch(self, subject: str) -> tuple[dict, str]:
        # Returns (parsed_schema_dict, schema_type) where schema_type is
        # "JSON", "AVRO", or "PROTOBUF".
        ...

# ── Type mapping tables ───────────────────────────────────────────────────
_JSON_TO_DBT: dict[str, str]   # JSON Schema type/format → dbt type
_AVRO_TO_DBT: dict[str, str]   # Avro primitive type → dbt type

# ── Schema → ColumnSpec ───────────────────────────────────────────────────
@dataclass
class ColumnSpec:
    name: str
    data_type: str

def schema_to_columns(schema: dict, schema_type: str) -> list[ColumnSpec]:
    # Dispatches on schema_type ("JSON" or "AVRO").
    # Protobuf raises NotImplementedError with a clear message.
    ...

# ── YAML renderers ────────────────────────────────────────────────────────
def render_sources_yaml(topic: str, schema_name: str, columns: list[ColumnSpec]) -> str:
    # Emits a sources: block matching the shape in models/sources.yaml,
    # with contract.enforced: true.
    ...

def render_model_yaml(model_name: str, columns: list[ColumnSpec]) -> str:
    # Emits a models: block matching src_hosts_models.yml,
    # with contract.enforced: false.
    ...
```

**Type mapping rules**

JSON Schema → dbt / Flink type:

| JSON Schema type / format | dbt type |
|---|---|
| `string` (no format) | `string` |
| `string` + `date-time` | `timestamp(3)` |
| `string` + `date` | `date` |
| `integer` | `int` |
| `number` | `double` |
| `boolean` | `boolean` |
| `array` | `array<string>` |
| `object` | `row<string>` |
| unknown / `null` / missing | `string` (safe fallback) |

Avro → dbt:

| Avro type | dbt type |
|---|---|
| `string` | `string` |
| `int` | `int` |
| `long` | `bigint` |
| `float` | `float` |
| `double` | `double` |
| `boolean` | `boolean` |
| `bytes` / `fixed` | `bytes` |
| union with `null` (nullable) | use non-null branch type |
| logical `timestamp-millis` / `timestamp-micros` | `timestamp(3)` |
| logical `date` | `date` |

**YAML output shapes**

`render_sources_yaml("raw_hosts", "raw_hosts", cols)` must produce:
```yaml
sources:
  - name: raw_hosts
    schema: <schema_name>
    tables:
      - name: raw_hosts
        columns:
          - name: host_id
            data_type: string
          ...
    config:
      contract:
        enforced: true
```

`render_model_yaml("src_hosts", cols)` must produce:
```yaml
models:
  - name: src_hosts
    config:
      contract:
        enforced: false
    columns:
      - name: host_id
        data_type: string
      ...
```

**Todo List**  
- [ ] Create `code/flink-sql/cm_py_lib/schema_registry.py` with the four
  sections above.
- [ ] `SchemaFetcher.__init__` imports
  `SCHEMA_REGISTRY_URL / _USER / _PASSWORD` from `kafka_json_producer` as
  defaults (same pattern as `kafka_avro_producer.py:27-33`).
- [ ] `SchemaFetcher.fetch` calls `get_latest_version(subject)` and parses
  the `schema_str` JSON. Returns `(schema_dict, schema_type)`.
- [ ] `schema_to_columns` for JSON Schema iterates `properties` keys; handles
  `anyOf`/`oneOf` with a null branch (Pydantic `Optional` pattern).
- [ ] `schema_to_columns` for Avro iterates `fields`; unwraps
  `["null", T]` unions; respects `logicalType`.
- [ ] `render_sources_yaml` / `render_model_yaml` use `yaml.safe_dump` with
  `sort_keys=False`, matching the style of `infer_seed_schema.py`.

**Relevant Context**  
- [`kafka_json_producer.py:112-114`](code/flink-sql/cm_py_lib/kafka_json_producer.py:112)
  — `SCHEMA_REGISTRY_URL / _USER / _PASSWORD` module-level constants.
- [`kafka_avro_producer.py:27-33`](code/flink-sql/cm_py_lib/kafka_avro_producer.py:27)
  — pattern for importing those constants from `kafka_json_producer`.
- [`kafka_avro_producer.py:87-93`](code/flink-sql/cm_py_lib/kafka_avro_producer.py:87)
  — `_create_schema_registry_client` pattern to copy into `SchemaFetcher`.
- [`models/sources.yaml`](code/dbt/airbnb_streaming/models/sources.yaml)
  — target YAML shape for `render_sources_yaml`.
- [`src_hosts_models.yml`](code/dbt/airbnb_streaming/models/user_reviews/sources/src_hosts_models.yml)
  — target YAML shape for `render_model_yaml`.
- [`infer_seed_schema.py`](code/dbt/airbnb_streaming/scripts/infer_seed_schema.py)
  — `yaml.safe_dump` style reference.

**Status** `[ ] pending`

---

### 3 — Create `tools/sr_to_dbt_yaml.py` (CLI entry point)

**Intent**  
Thin CLI wrapper. Resolves `sys.path` to find `cm_py_lib` (same pattern as
`produce_to_kafka.py`), parses args, calls the library functions, prints
result to stdout.

**Expected Outcomes**  
These all work from `tools/`:

```sh
# value schema only, sources block (defaults)
uv run sr_to_dbt_yaml.py raw_hosts

# both key and value schemas
uv run sr_to_dbt_yaml.py raw_hosts --subject-suffix key,value

# model YAML block
uv run sr_to_dbt_yaml.py raw_hosts --output model

# explicit credentials (override env)
uv run sr_to_dbt_yaml.py raw_hosts \
  --sr-url https://psrc-xxx.us-east-2.aws.confluent.cloud \
  --sr-key ABCDEF \
  --sr-secret mysecret
```

**CLI flags**

| Flag | Default | Description |
|---|---|---|
| `topic` | (positional, required) | Kafka topic name |
| `--subject-suffix` | `value` | `key`, `value`, or `key,value` |
| `--output` | `sources` | `sources` or `model` |
| `--schema-name` | topic name | Override the `name:` / `schema:` in the YAML |
| `--sr-url` | `$SCHEMA_REGISTRY_ENDPOINT` or `$SCHEMA_REGISTRY_URL` | Schema Registry URL |
| `--sr-key` | `$SCHEMA_REGISTRY_API_KEY` | SR API key |
| `--sr-secret` | `$SCHEMA_REGISTRY_API_SECRET` | SR API secret |

Env var fallback order (CLI flag > env):
- URL: `SCHEMA_REGISTRY_URL`, `SCHEMA_REGISTRY_ENDPOINT`
- Key: `SCHEMA_REGISTRY_API_KEY`, `SCHEMA_REGISTRY_USER`
- Secret: `SCHEMA_REGISTRY_API_SECRET`, `SCHEMA_REGISTRY_PASSWORD`

**`sys.path` discovery** — copy the `flink_sql_root()` + `setup_cm_py_lib()`
pattern from
[`produce_to_kafka.py:73-95`](code/dbt/airbnb_streaming/scripts/produce_to_kafka.py:73).

**Todo List**  
- [ ] Create `tools/sr_to_dbt_yaml.py`.
- [ ] Implement `_cm_py_lib_root()` path discovery (walk parents looking for
  `code/flink-sql/cm_py_lib/schema_registry.py`).
- [ ] `build_arg_parser()` defines all flags above.
- [ ] `main()` resolves credentials (CLI > env fallback), constructs
  `SchemaFetcher`, iterates suffixes, calls `schema_to_columns` and the
  appropriate renderer, prints to stdout.
- [ ] Errors (SR unreachable, subject not found, Protobuf) print to stderr,
  exit 1.

**Relevant Context**  
- [`produce_to_kafka.py:73-95`](code/dbt/airbnb_streaming/scripts/produce_to_kafka.py:73)
  — `flink_sql_root()` / `setup_cm_py_lib()` path-discovery pattern to copy.
- `code/flink-sql/cm_py_lib/schema_registry.py` — created in sub-task 2.

**Status** `[ ] pending`

---

### 4 — Update `tools/README.md`

**Intent**  
Document the new tool so it is discoverable without reading the source.

**Todo List**  
- [ ] Add a `## Schema Registry → dbt YAML` section with purpose, required
  env vars, and usage examples (sources block, model block, both subjects,
  explicit credentials).

**Relevant Context**  
- [`tools/README.md`](tools/README.md) — existing README to extend.

**Status** `[ ] pending`
