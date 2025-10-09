# Payment Event Generator

A Python-based Kafka claim transaction event generator for the external lookup demonstration. This component generates realistic payment events containing `claim_id` references that will be enriched by external database lookups in the Flink streaming application.

## Overview

This event generator produces realistic payment transactions to Kafka topics, simulating a high-volume payment processing system. The events contain claim ID references that need to be enriched with insurance claim metadata from an external database.

## Features

### Claim payment Data Generation
- Faker-based payment data generation
- Multiple payment methods (ACH, WIRE, CHECK, CARD, ELECTRONIC)
- Configurable amount ranges and distributions
- Event timestamps and reference numbers

### Flexible Event Scenarios
- **Normal Operations** (70%) - Standard business flow
- **High-Value Payments** (15%) - Large transaction amounts
- **Error Testing** (15%) - Invalid claim IDs for failure testing

### Multiple Generation Modes
- **Continuous Mode** - Steady event rate (default)
- **Burst Mode** - Events in periodic bursts
- **Dry Run Mode** - Test without sending to Kafka

### Monitoring & Observability
- Prometheus metrics for production monitoring
- Rich CLI with progress tracking
- Detailed logging and statistics
- Health checks and validation

### Deployment Options
- Local development with uv
- Docker container deployment
- Kubernetes with multiple variants
- CI/CD ready configuration

## Quick Start

### 1. Local Development

```bash
# Install with uv (recommended)
uv venv
source .venv/bin/activate  # or `.venv\Scripts\activate` on Windows
uv sync


# Run with default settings
payment-generator generate --rate 5 --duration 30

# Test scenarios
payment-generator scenarios

# Dry run mode
payment-generator generate --dry-run --rate 2 --duration 10
```

### 2. Docker Deployment

```bash
# Build container
make build

# Test locally
docker run -e PAYMENT_GEN_DRY_RUN=true external-lookup-event-generator:latest \
    generate --rate 5 --duration 10

# Run with Kafka
docker run \
    -e PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
    external-lookup-event-generator:latest \
    generate --rate 10 --duration 60
```

### 3. Kubernetes Deployment

* Define the schema to the schema registry:
  ```sh
  # Be sure the schema end point is visible
  make port_forward_schema_registry
  make publish_schema
  ```

* Deploy all resources
  ```bash
  make deploy
  ```

* Check status
```sh
make status
kubectl get pods -l app=external-lookup-event-generator -n el-demos
```

## Configuration

### Environment Variables

Key configuration options (prefix with `PAYMENT_GEN_`):

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka connection |
| `KAFKA_TOPIC` | `payment-events` | Target topic |
| `EVENTS_PER_SECOND` | `10.0` | Generation rate |
| `RUN_DURATION_SECONDS` | `300` | Runtime (0=infinite) |
| `VALID_CLAIM_RATE` | `0.85` | Valid claim ID ratio |
| `BURST_MODE` | `false` | Enable burst generation |
| `DRY_RUN` | `false` | Test without Kafka |
| `LOG_LEVEL` | `INFO` | Logging verbosity |

### Event Schema

Generated payment events follow this structure:

```json
{
  "payment_id": "PAY-A1B2C3D4",
  "claim_id": "CLM-001",
  "payment_amount": 1250.50,
  "payment_date": "2024-01-15T10:30:00Z",
  "processor_id": "PROC-VISA-001",
  "payment_method": "ELECTRONIC",
  "payment_status": "PENDING",
  "reference_number": "REF-ABC123DEF456",
  "transaction_id": "TXN-1234567890ABCDEF",
  "notes": "Automated payment processing",
  "created_by": "event-generator"
}
```

## CLI Commands

### Generate Events
```bash
# Basic usage
payment-generator generate

# Custom rate and duration
payment-generator generate --rate 20 --duration 120

# Burst mode
payment-generator generate --burst --burst-size 100 --burst-interval 30

# High error rate for testing
payment-generator generate --valid-rate 0.3 --print-events
```

### Testing & Validation
```bash
# List available scenarios
payment-generator scenarios

# Test Kafka connectivity
payment-generator test-kafka --kafka-servers localhost:9092 --count 5

# Validate claims database
payment-generator validate-claims --database-url http://localhost:8080
```

## Kubernetes Variants

### Standard Deployment
- **Rate**: 10 events/second
- **Mode**: Continuous
- **Use**: Normal development and testing

### High-Rate Deployment  
- **Rate**: 50 events/second
- **Mode**: Continuous
- **Use**: Performance and throughput testing

### Burst Deployment
- **Mode**: Burst (200 events every 60 seconds)
- **Use**: Testing burst load handling

### Error-Test Deployment
- **Rate**: 5 events/second
- **Valid Claims**: Only 30%
- **Use**: Error handling validation

## Monitoring

### Prometheus Metrics

Available at `http://localhost:8090/metrics`:

- `payment_events_produced_total` - Total events produced
- `payment_events_failed_total` - Failed productions
- `kafka_delivery_duration_seconds` - Delivery latency
- `payment_events_per_second` - Current generation rate

### Kubernetes Access

```bash
# Port forward for metrics
kubectl port-forward svc/event-generator-metrics 8090:8090

# View logs
kubectl logs -l app=external-lookup-event-generator -f

# Check pod status
kubectl get pods -l app=external-lookup-event-generator
```

## Test Data

### Valid Claim IDs (85% default)
Events use these claim IDs that exist in the database:
- `CLM-001` to `CLM-020` - Standard claims
- `CLAIM-TEST-001` to `CLAIM-TEST-005` - Specific test data

### Invalid Claim IDs (15% default)
Events use these non-existent claim IDs for error testing:
- `CLAIM-INVALID-001`, `CLAIM-INVALID-002`
- `CLAIM-MISSING-001`, `CLAIM-NONEXISTENT-001`

## Integration

The event generator is designed to work seamlessly with:

2. **Flink Streaming App** - Processes events and performs lookups
3. **Kafka Infrastructure** - Event streaming platform
4. **Monitoring Stack** - Prometheus/Grafana for observability

## Development

### Local Setup
```bash
# Install development dependencies
uv pip install -e ".[dev]"

# Run tests
pytest

# Code formatting
black src/ tests/
isort src/ tests/

# Type checking
mypy src/
```

### Building
```bash
# Build Docker image
./build-image.sh

# Build Python package
uv build
```

## Troubleshooting

### Common Issues

**Kafka Connection Failed**
```bash
# Check Kafka availability
telnet localhost 9092

# Test with dry run first
payment-generator generate --dry-run
```

**High Memory Usage**
```bash
# Reduce batch size
export PAYMENT_GEN_KAFKA_BATCH_SIZE=8192

# Lower generation rate
payment-generator generate --rate 5
```

**Invalid Claims Not Working**
```bash
# Validate database connection
payment-generator validate-claims --database-url http://localhost:8080
```

### Logs and Debugging

```bash
# Verbose logging
export PAYMENT_GEN_LOG_LEVEL=DEBUG

# Print events to console
payment-generator generate --print-events --rate 1

# Container logs
docker logs <container-id> -f
```

## Next Steps

This event generator is ready for integration with:
- ✅ **DuckDB Database** (implemented) Just for testing DB connection as part of the CLI
- ✅**Flink Streaming Application**
- ✅ **Kafka Topic Configuration** 
- 🚧 **End-to-End Testing Framework**
