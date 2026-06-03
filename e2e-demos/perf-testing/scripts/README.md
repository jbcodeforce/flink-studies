# Automation Scripts

Scripts for the perf-testing demo. Run Phase 1 end-to-end in order.

## Phase 1 — Local

| Script | Purpose |
|--------|---------|
| [build-all.sh](build-all.sh) | `mvn package` for producer, sql-executor, datastream (`SKIP_TESTS=true` to skip tests) |
| [create-topics-local.sh](create-topics-local.sh) | Create topics via `kafka-topics` (needs `BOOTSTRAP_SERVERS`) |
| [run-producer.sh](run-producer.sh) | Run data generator JAR |
| [run-flink-job.sh](run-flink-job.sh) | `flink run` for `sql-executor` or `datastream` |
| [validate-run.sh](validate-run.sh) | Consume sample records from `perf-output` |

## Phase 2 — Kubernetes

| Script | Purpose |
|--------|---------|
| [create-topics.sh](create-topics.sh) | Apply CP `KafkaTopic` CRs (`kubectl`, namespace `kafka`) |
| [deploy-k8s-oss.sh](deploy-k8s-oss.sh) | Build OSS image + apply `oss-flink/k8s/flink-deployment.yaml` |
| [deploy-k8s-cp.sh](deploy-k8s-cp.sh) | Build CP image + apply topics + `cp-flink/k8s/flink-application.yaml` |
| [run-benchmark-k8s.sh](run-benchmark-k8s.sh) | Topics → deploy job → producer Job → validate |

## Helpers

| Script | Purpose |
|--------|---------|
| [helpers/port-forward-kafka-macos.sh](helpers/port-forward-kafka-macos.sh) | macOS: open Terminal with `kubectl port-forward` to Kafka |

## Metrics

Flink UI and `kafka-consumer-groups` are manual for now. See parent [README](../README.md).
