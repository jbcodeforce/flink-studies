# Data Generator (Standalone Kafka Producer)

Standalone Kafka producer for Flink performance tests.

## Schema (JSON value)

`id` (long), `event_time` (ISO-8601 string), `value` (double), `payload` (string, sized to target bytes).

## Build

```bash
mvn -f pom.xml clean package
# JAR: target/perf-data-generator-0.1.0.jar
```

Or from demo root: `./scripts/build-all.sh`

## Run locally

```bash
export BOOTSTRAP_SERVERS=localhost:9092
./scripts/run-producer.sh 1000 60
```

### Environment / args

| Env / arg | Default |
|-----------|---------|
| `BOOTSTRAP_SERVERS` | required |
| `TOPIC` / arg1 | `perf-input` |
| `RATE_PER_SEC` / arg2 | `1000` |
| `MESSAGE_SIZE_BYTES` / arg3 | `256` |
| `DURATION_SECONDS` / arg4 | `60` |
| `NUM_THREADS` / arg5 | `1` |

Stdout reports total sent and effective msg/s.

## Docker

```bash
docker build -t perf-data-generator:0.1.0 .
docker run --rm \
  -e BOOTSTRAP_SERVERS=host.docker.internal:9092 \
  -e RATE_PER_SEC=5000 \
  perf-data-generator:0.1.0
```

## Kubernetes

1. Edit `k8s/configmap.yaml` bootstrap if needed.
2. `docker build -t perf-data-generator:0.1.0 .` and load into cluster.
3. `kubectl apply -f k8s/configmap.yaml -f k8s/job.yaml`

See parent [README](../README.md).
