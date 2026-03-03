# Data Generator (Standalone Kafka Producer)

Standalone Kafka producer used to feed input topics for Flink performance runs.  Pattern inspired by Robert Metzger's DataGeneratorJob-style generators.

## Responsibilities

- Produce records to one or more Kafka topics with configurable:
  - Target rate (messages per second) or max throughput.
  - Message size and payload format (e.g. JSON with fixed/variable fields).
  - Number of producer threads.
- Emit payloads that match the schema expected by Flink jobs in `../flink-jobs/` (e.g. key, value, optional event-time field for latency measurement).

## Implementation Options

- **Java**: Kafka Producer API; tune batch size, linger.ms, compression; optional Schema Registry for Avro/JSON Schema.
- **CLI/config**: Bootstrap servers, topic name(s), rate, size, duration, and optional key/value schema passed via config or env.

## Output

- Topics and serialization (JSON, Avro, etc.) must match the source tables or connectors used in `../flink-jobs/sql-executor`, `../flink-jobs/datastream`, and `../flink-jobs/flink-sql`.

## Calibration

See parent [README](../README.md): calibrate with different thread counts and message sizes; refer to [Optimize producer throughput](https://developer.confluent.io/confluent-tutorials/optimize-producer-throughput/kafka/) for tuning.

## Docker

Build the image from the producer directory:

```bash
docker build -t perf-data-generator:0.1.0 .
```

Run with env (e.g. override bootstrap and rate):

```bash
docker run --rm -e BOOTSTRAP_SERVERS=host.docker.internal:9092 -e RATE_PER_SEC=5000 perf-data-generator:0.1.0
```

## Kubernetes

Manifests in `k8s/` deploy the producer as a one-off Job (runs for the configured duration then exits).

1. Set `BOOTSTRAP_SERVERS` in `k8s/configmap.yaml` to your Kafka bootstrap (e.g. `kafka.kafka.svc.cluster.local:9092`). Adjust `RATE_PER_SEC`, `DURATION_SECONDS`, `TOPIC` as needed.
2. Build and load the image into your cluster (or push to a registry and set `image` + `imagePullPolicy` in `k8s/job.yaml`).
3. Apply and run:

```bash
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/job.yaml
kubectl logs -f job/perf-producer
```

To override env for a single run, patch the Job or set env in the container spec. Delete the Job after use; `ttlSecondsAfterFinished: 3600` cleans it up one hour after completion.
