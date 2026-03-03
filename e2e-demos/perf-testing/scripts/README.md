# Automation Scripts

Scripts to drive the e2e performance assessment: environment, topics, producer, Flink jobs, and metrics.

## Suggested Scripts

- **Topics**: Create (and optionally delete) Kafka topics used by the producer and Flink jobs; set partition count and retention.
- **Producer**: Run the data generator in `../producer/` with a given profile (rate, message size, duration, topic).
- **Flink**: Submit or deploy the chosen job from `../flink-jobs/` (e.g. `flink run` JAR, or platform-specific deploy).
- **Metrics**: Query Flink REST (throughput, backpressure) and/or Prometheus; optionally export consumer lag (e.g. kafka-consumer-groups or admin API).

## Usage

Run in order for a full benchmark: (1) create topics, (2) start producer, (3) deploy Flink job, (4) collect metrics for a fixed window, (5) stop producer and job. See parent [README](../README.md) for the full approach.
