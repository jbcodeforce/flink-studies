# End-to-End Performance Assessment for Flink Jobs

Created 02/06/2026 · Updated 02/06/2026

Repeatable throughput and latency benchmarking: a standalone Kafka producer feeds Flink job variants; results land on an output topic for validation and observability.

![](../../docs/cookbook/images/perf_test_basic.drawio.png)

Architecture overview: [docs/arch.drawio.png](./docs/arch.drawio.png)

## Goals

- Measure throughput (events/s) and latency (source → sink) for Flink jobs.
- Compare Table API + SQL (`sql-executor`), DataStream (`datastream`), and Flink SQL (`flink-sql` / `cccloud`).
- Keep the data generator separate from Flink so rate and message size are tuned independently.

## Flink and platform versions

| Component | Version |
|-----------|---------|
| Apache Flink (jobs) | **2.2.0** |
| Kafka connector | `flink-connector-kafka` **5.0.0-2.2** |
| CP / CMF image (Phase 2) | `confluentinc/cp-flink:2.2.0-cp2-java21` |
| OSS image (Phase 2) | `flink:2.2.0-scala_2.12-java17` |

Align local clusters with [deployment/k8s/cmf](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/cmf) and [deployment/product-tar/install-flink-local.sh](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/product-tar/install-flink-local.sh) (`./install-flink-local.sh 2.2.0`). Do not use [deployment/docker/flink-oss-docker-compose.yaml](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/docker/flink-oss-docker-compose.yaml) (still on 1.19.1) for this demo.

## Deployment matrix

| Phase | Path | Flink runtime | Kafka | Job form |
|-------|------|---------------|-------|----------|
| 1 | [Phase 1 — Local](#phase-1--local) | `flink run` or CMF 2.2 | Any reachable bootstrap | Java JAR |
| 2 | [oss-flink/](oss-flink/) · [cp-flink/](cp-flink/) | K8s FKO or CMF | In-cluster / port-forward | JAR in image |
| 3 | [cccloud/](cccloud/) | Confluent Cloud for Flink | CC Kafka | SQL statements |

## Environment variables

| Variable | Required | Default | Used by |
|----------|----------|---------|---------|
| `BOOTSTRAP_SERVERS` | yes | — | producer, Flink jobs, scripts |
| `INPUT_TOPIC` | no | `perf-input` | jobs, producer |
| `OUTPUT_TOPIC` | no | `perf-output` | jobs, validate |
| `RATE_PER_SEC` | no | `1000` | producer |
| `MESSAGE_SIZE_BYTES` | no | `256` | producer |
| `DURATION_SECONDS` | no | `60` | producer |
| `NUM_THREADS` | no | `1` | producer |
| `FLINK_HOME` | Phase 1 | — | `run-flink-job.sh` (`flink` CLI) |

---

## Phase 1 — Local

**Prerequisites:** Java 17+, Maven, Kafka bootstrap, Flink **2.2.0** on `PATH` (`$FLINK_HOME/bin/flink`).

### Steps

```bash
cd e2e-demos/perf-testing

# 1. Build
./scripts/build-all.sh

# 2. Topics (kafka-topics CLI)
export BOOTSTRAP_SERVERS=localhost:9092
./scripts/create-topics-local.sh

# 3. Start Flink job (separate terminal; blocks)
export BOOTSTRAP_SERVERS=localhost:9092
./scripts/run-flink-job.sh sql-executor
# or: ./scripts/run-flink-job.sh datastream

# 4. Generate load
./scripts/run-producer.sh 1000 60

# 5. Validate output topic
./scripts/validate-run.sh
```

### Metrics (manual)

- Flink Web UI: records in/out, backpressure, checkpoints.
- `kafka-consumer-groups --bootstrap-server $BOOTSTRAP_SERVERS --describe --group perf-datastream` (DataStream job).
- Payload `event_time` field supports end-to-end latency analysis if you compare with consume time.

### Troubleshooting

| Symptom | Check |
|---------|--------|
| `BOOTSTRAP_SERVERS is required` | Export bootstrap before scripts |
| JAR not found | Run `./scripts/build-all.sh` |
| No output on validate | Job running? Producer on `perf-input`? Topics exist? |
| JSON / planner errors on `flink run` | Use Flink **2.2.0**; shaded JAR includes kafka + json connectors |
| macOS Kafka port-forward | `./scripts/helpers/port-forward-kafka-macos.sh` |

---

## Phase 2 — Kubernetes

Deploy the same JARs on Kubernetes after Phase 1 builds succeed.

| Variant | Folder | Apply |
|---------|--------|-------|
| OSS Flink Kubernetes Operator | [oss-flink/](oss-flink/) | `./oss-flink/flink-sql-executor/build.sh` then `./scripts/deploy-k8s-oss.sh` |
| Confluent Manager for Flink (CP) | [cp-flink/](cp-flink/) | `./cp-flink/build.sh` then `./scripts/deploy-k8s-cp.sh` |

Shared assets:

- Topics (CP operator): `./scripts/create-topics.sh` → [k8s/perf-input.yaml](k8s/perf-input.yaml), [perf-output.yaml](k8s/perf-output.yaml)
- Producer Job: [producer/k8s/](producer/k8s/)
- Full benchmark: `./scripts/run-benchmark-k8s.sh cp|oss`

See [oss-flink/README.md](oss-flink/README.md) and [cp-flink/README.md](cp-flink/README.md).

---

## Phase 3 — Confluent Cloud for Flink

SQL-only path: [cccloud/](cccloud/) — DDL/DML for `perf_source` → `perf_sink`, plus optional `deploy-statements.sh`.

Use Phase 1 producer against CC Kafka bootstrap (SASL/SSL via standard Kafka client env). See [cccloud/README.md](cccloud/README.md).

---

## Components

| Folder | Role |
|--------|------|
| [producer/](producer/) | Standalone Kafka load generator |
| [flink-jobs/](flink-jobs/) | `sql-executor`, `datastream`, `flink-sql` |
| [scripts/](scripts/) | Build, topics, run, validate, K8s deploy |
| [k8s/](k8s/) | CP `KafkaTopic` CRs |

## References

- [Job lifecycle — performance testing](https://jbcodeforce.github.io/flink-studies/cookbook/job_lifecycle/#60-establish-a-performance-testing-platform)
- [K8s tuning lab §10](https://jbcodeforce.github.io/flink-studies/cookbook/k8s_tuning/#10--lab-overview--tune-and-observe-a-flinkapplication)
- [Optimize Kafka producer throughput](https://developer.confluent.io/confluent-tutorials/optimize-producer-throughput/kafka/)
- [Apache Flink 2.2 documentation](https://nightlies.apache.org/flink/flink-docs-release-2.2/)
