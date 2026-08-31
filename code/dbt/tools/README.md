# Tools for dbt project management

## dbt project management

dbt init is creating very simple project, and we may want to adopt a  data product with star schema first or kimball with data product.

### Usage 

* Initialise a kimball project named crm-analytics in a folder ./crm-analytics, using an existing dbt profile

```sh
uv run tools/sl_dbt.py init crm-analytics --type kimball --profile cc_flink
```

* Initialise a data products project named crm-analytics in a folder ./crm-analytics
```sh
uv run tools/sl_dbt.py init crm-analytics --profile cc_flink
```

* Add a data product
```sh
uv run tools/sl_dbt.py add-data-product crm-analytics c360
```

* Add a table `src_customers` for a data product `c360` to the crm-analytics project 

```sh
uv run tools/sl_dbt.py add-table crm-analytics src_customers c360 --table-type dim
```

---

## Schema Registry → dbt YAML

`sr_to_dbt_yaml.py` fetches the key and/or value schema registered in Confluent Schema Registry for a given Kafka topic and emits a ready-to-paste dbt model YAML block. Supports **JSON Schema** and **Avro** subjects.

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

---

## dbt SQL → dbt Model YAML

`sql_to_dbt_yaml.py` parses a dbt SQL model file and emits a ready-to-paste `models:` YAML block, resolving column names and data types entirely from the SQL and the upstream model / source definitions in the project.

It handles:
- `{{ ref('model') }}` and `{{ source('schema', 'table') }}` Jinja calls
- `SELECT *` chains (recursively expands from upstream YAML)
- `CAST(expr AS type)` — extracts the target type directly
- `GREATEST(a, b)`, `LEAST(a, b)` — inherits type from the first resolvable argument
- `COALESCE(col, default)` — inherits type from the first non-literal argument
- `CASE WHEN … THEN … ELSE … END` — inherits type from the first resolvable branch
- Plain column pass-throughs and aliases
- Backtick-quoted identifiers (normalised to double-quotes for parsing)

### Usage

```sh
# Auto-detect project root (walks up from the SQL file to find dbt_project.yml)
uv run sql_to_dbt_yaml.py ../airbnb_streaming/models/user_reviews/dimensions/dim_listings_with_hosts.sql

# Explicit project root
uv run sql_to_dbt_yaml.py path/to/model.sql --project-root ../airbnb_streaming

# Override the model name in the YAML output
uv run sql_to_dbt_yaml.py path/to/model.sql --model-name my_custom_name
```

### Example — `dim_listings_with_hosts.sql`

`dim_listings_with_hosts` JOINs `dim_listings_cleansed` (via `src_listings` →
`raw_listings`) with `dim_hosts_cleansed` (via `src_hosts` → `raw_hosts`).
The tool resolves all four layers automatically:

```sh
uv run sql_to_dbt_yaml.py ../airbnb_streaming/models/user_reviews/dimensions/dim_listings_with_hosts.sql
```

```yaml
models:
- name: dim_listings_with_hosts
  config:
    contract:
      enforced: false
  columns:
  - name: listing_id
    data_type: varchar(2147483647)
  - name: listing_name
    data_type: varchar(2147483647)
  - name: room_type
    data_type: varchar(2147483647)
  - name: minimum_nights
    data_type: bigint
  - name: price
    data_type: decimal(10,2)
  - name: host_id
    data_type: varchar(2147483647)
  - name: host_name
    data_type: varchar(2147483647)
  - name: host_is_superhost
    data_type: boolean
  - name: created_at
    data_type: varchar(2147483647)
  - name: updated_at
    data_type: varchar(2147483647)
```

### Module structure

| File | Role |
|---|---|
| `sql_to_dbt_yaml.py` | CLI entry point |
| `sql_parser.py` | Strips Jinja, parses SELECT list into `SelectItem` dataclass |
| `model_resolver.py` | Finds model/source YAML files and resolves column lists recursively |
| `type_inferrer.py` | Maps SQL expressions to dbt/Flink type strings |

---

### Reusable library

The schema-fetching and YAML-rendering logic lives in `code/flink-sql/cm_py_lib/schema_registry.py` and can be imported directly from any script in the repo:

```python
from cm_py_lib.schema_registry import SchemaFetcher, schema_to_columns, render_sources_yaml

fetcher = SchemaFetcher()                              # reads env vars
schema, schema_type = fetcher.fetch("raw_hosts-value")
columns = schema_to_columns(schema, schema_type)
print(render_sources_yaml("raw_hosts", "j9r-kafka", columns))
```

---

## Flink DML query to dbt project

[See dedicated README](./flink_dbt_migrate/README.md)