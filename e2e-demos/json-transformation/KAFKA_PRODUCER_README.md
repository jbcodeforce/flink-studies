# Kafka JSON Producer

A flexible Python Kafka producer for sending JSON records, designed for the Shift Left Utils project.

## Features

- **Multiple Record Types**: Support for AMX records, execution state records, and custom JSON
- **Pydantic Models**: Type-safe record definitions with validation
- **Environment Configuration**: Secure configuration via environment variables
- **Delivery Reports**: Built-in callback handling for message delivery confirmation
- **CLI Interface**: Command-line interface for easy testing and automation

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements_kafka.txt
```

### 2. Set Environment Variables

```bash
# Basic configuration
export KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
export KAFKA_TOPIC="my-topic"

# For secured clusters (optional)
export KAFKA_USER="your-username"
export KAFKA_PASSWORD="your-password"
export KAFKA_SECURITY_PROTOCOL="SASL_SSL"
export KAFKA_SASL_MECHANISM="PLAIN"
export KAFKA_CERT="/path/to/cert.pem"
```

### 3. Usage Examples

#### Command Line Interface

```bash
# Send 5 simple events
python kafka_json_producer.py --record-type simple --count 5

# Send AMX records continuously
python kafka_json_producer.py --record-type amx --topic amx-records

# Send custom JSON
python kafka_json_producer.py --custom-json '{"test": "data", "timestamp": "2024-01-15T10:30:00Z"}' --topic custom --key test_001
```

#### Programmatic Usage

```python
from kafka_json_producer import KafkaJSONProducer, generate_amx_record

# Create producer
producer = KafkaJSONProducer("my-topic")

# Send a structured record
record = generate_amx_record()
producer.send_record(record)

# Send custom JSON
custom_data = {"id": "123", "name": "test", "value": 42}
producer.send_json_dict(custom_data, key="123")

# Clean up
producer.flush_and_close()
```

## Record Types

### 1. AMX Record (`--record-type amx`)
Based on the `src_amx_record` schema, includes fields like:
- `id`, `tenantId`, `title`
- `status`, `percentComplete`
- `createdOnDate`, `createdByUserId`
- And many more AMX-specific fields

### 2. Execution State Record (`--record-type execution_state`)
Based on the `record_execution_state_record` model, includes:
- `id`, `ts_ms`, `tenant_id`, `app_id`
- `recordname`, `recordtype`, `recordStatus`
- Workflow and execution-related fields

### 3. Simple Event (`--record-type simple`)
Lightweight event structure for testing:
- `event_id`, `event_type`, `timestamp`
- `user_id`, `data` (flexible dictionary)

### 4. Custom JSON (`--custom-json`)
Send any JSON structure directly

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka broker addresses |
| `KAFKA_TOPIC` | `test-records` | Default topic name |
| `KAFKA_USER` | _(empty)_ | SASL username |
| `KAFKA_PASSWORD` | _(empty)_ | SASL password |
| `KAFKA_SECURITY_PROTOCOL` | `PLAINTEXT` | Security protocol |
| `KAFKA_SASL_MECHANISM` | `PLAIN` | SASL mechanism |
| `KAFKA_CERT` | _(empty)_ | SSL certificate path |

## Integration with Shift Left CLI

This producer complements the existing `shift_left` CLI commands:

```bash
# List available topics first
shift_left project list-topics $PIPELINES

# Send test data to a specific topic
python kafka_json_producer.py --record-type amx --topic src_amx_record --count 10

# Deploy pipelines to process the data
shift_left pipeline deploy $PIPELINES/table_inventory.json
```

## Examples

See `example_usage.py` for comprehensive usage examples including all record types and different sending patterns.