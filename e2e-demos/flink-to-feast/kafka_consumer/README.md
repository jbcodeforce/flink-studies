# Kafka Consumer for Feast Integration

A production-ready Kafka consumer that consumes messages from Kafka using Confluent Schema Registry (Avro), transforms them, and pushes data to Feast feature store.

## Overview

This consumer application:
- Consumes Avro-encoded messages from Kafka topics using Confluent Schema Registry
- Transforms messages to match Feast push source schema
- Pushes data to Feast feature store (`driver_stats_push_source`)
- Provides health check endpoints for Kubernetes liveness/readiness probes
- Includes error handling, retry logic, and structured logging

## Architecture

```
Kafka Topic → Consumer (Avro Deserializer) → Message Transform → Feast Push → Online Store
                ↓
         Health Check Server (HTTP :8080)
```

## Prerequisites

- Python 3.12+
- Kafka cluster with Schema Registry
- Feast feature repository configured
- Access to Feast online store

## Installation

### Local Development

1. Install dependencies using uv:
```bash
uv sync
```

2. Set up environment variables (see Configuration section)

3. Run the consumer:
```bash
uv run python -m kafka_consumer.main
```

### Docker

Build the Docker image:
```bash
docker build -t jbcodeforce/kafka-feast-consumer:latest .
```

Run the container:
```bash
docker run -e KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
           -e KAFKA_TOPIC=driver-stats \
           -e SCHEMA_REGISTRY_URL=http://localhost:8081 \
           -e FEAST_REPO_PATH=/app/feature_repo \
           -v $(pwd)/feature_repo:/app/feature_repo \
           jbcodeforce/kafka-feast-consumer:latest
```

## Configuration

Configuration is managed through environment variables. All settings have sensible defaults.

### Required Configuration

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (comma-separated)
- `KAFKA_TOPIC`: Kafka topic name to consume from
- `SCHEMA_REGISTRY_URL`: Schema Registry endpoint URL
- `FEAST_REPO_PATH`: Path to Feast feature repository

### Optional Configuration

- `KAFKA_CONSUMER_GROUP`: Consumer group ID (default: `feast-consumer-group`)
- `KAFKA_AUTO_OFFSET_RESET`: Offset reset policy (default: `earliest`)
- `KAFKA_ENABLE_AUTO_COMMIT`: Enable auto commit (default: `true`)
- `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO`: Schema Registry auth (format: `username:password`)
- `HEALTH_CHECK_PORT`: Health check server port (default: `8080`)
- `LOG_LEVEL`: Logging level (default: `INFO`)
- `BATCH_SIZE`: Messages to batch before pushing (default: `1`)
- `MAX_RETRIES`: Maximum retries for failed operations (default: `3`)
- `RETRY_BACKOFF_MS`: Initial backoff time in milliseconds (default: `1000`)

## Message Schema

The consumer expects Kafka messages in Avro format with the following fields:

**Required:**
- `driver_id`: Entity identifier (integer or string)

**Optional:**
- `event_timestamp`: Event timestamp (datetime, Unix timestamp, or ISO string)
- `created`: Created timestamp (datetime, Unix timestamp, or ISO string)
- `conv_rate`: Conversion rate (float)
- `acc_rate`: Acceptance rate (float)
- `avg_daily_trips`: Average daily trips (integer)

If `event_timestamp` or `created` are not present, they default to the current time.

## Kubernetes Deployment

### 1. Create ConfigMap

Update `k8s/configmap.yaml` with your configuration values, then apply:

```bash
kubectl apply -f k8s/configmap.yaml
```

### 2. Create Secrets (if needed)

Copy `k8s/secret.yaml.example` to `k8s/secret.yaml` and fill in credentials:

```bash
cp k8s/secret.yaml.example k8s/secret.yaml
# Edit k8s/secret.yaml with your credentials
kubectl apply -f k8s/secret.yaml
```

### 3. Create Feast Feature Repository ConfigMap

The Feast feature repository needs to be available as a ConfigMap:

```bash
kubectl create configmap feast-feature-repo \
  --from-file=feature_repo/ \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 4. Deploy the Consumer

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -l app=kafka-feast-consumer

# Check logs
kubectl logs -f deployment/kafka-feast-consumer

# Check health
kubectl port-forward svc/kafka-feast-consumer 8080:8080
curl http://localhost:8080/health
```

## Health Checks

The application provides several health check endpoints:

- `GET /health`: Basic health check (always returns 200)
- `GET /health/live`: Liveness probe (checks if service is alive)
- `GET /health/ready`: Readiness probe (checks Kafka, Schema Registry, and Feast connectivity)
- `GET /metrics`: Metrics endpoint (messages consumed, pushed, errors, etc.)

## Monitoring

### Metrics

The `/metrics` endpoint provides:
- `messages_consumed`: Total messages consumed
- `messages_pushed`: Total messages successfully pushed to Feast
- `errors`: Total errors encountered
- `last_message_time`: Timestamp of last processed message

### Logging

The application uses structured logging with configurable log levels. Logs include:
- Message processing status
- Error details with stack traces
- Health check results
- Consumer lifecycle events

## Troubleshooting

### Consumer not receiving messages

1. Check Kafka connectivity:
```bash
kubectl exec -it <pod-name> -- python -c "from confluent_kafka import Consumer; c = Consumer({'bootstrap.servers': 'kafka:9092', 'group.id': 'test'}); print(c.list_topics())"
```

2. Verify topic exists and has messages:
```bash
kubectl exec -it <kafka-pod> -- kafka-console-consumer --bootstrap-server localhost:9092 --topic driver-stats --from-beginning
```

### Schema Registry errors

1. Check Schema Registry connectivity:
```bash
curl http://schema-registry:8081/subjects
```

2. Verify schema exists for the topic:
```bash
curl http://schema-registry:8081/subjects/driver-stats-value/versions
```

### Feast push failures

1. Check Feast store connectivity:
```bash
kubectl exec -it <pod-name> -- python -c "from feast import FeatureStore; store = FeatureStore(repo_path='/app/feature_repo'); print('OK')"
```

2. Verify push source exists:
```bash
kubectl exec -it <pod-name> -- python -c "from feast import FeatureStore; store = FeatureStore(repo_path='/app/feature_repo'); print(store.list_data_sources())"
```

### Health check failures

Check the readiness probe:
```bash
kubectl get pods -l app=kafka-feast-consumer
kubectl describe pod <pod-name>
```

View health check logs:
```bash
kubectl logs <pod-name> | grep -i health
```

## Development

### Running Tests

```bash
uv run pytest tests/
```

### Code Structure

```
kafka_consumer/
├── __init__.py
├── main.py              # Entry point
├── config.py            # Configuration management
├── consumer.py          # Kafka consumer logic
├── feast_client.py      # Feast integration
├── health.py            # Health check server
└── utils.py             # Utility functions
```

## License

See main project LICENSE file.
