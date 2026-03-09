# Perf testing – OSS Flink

## Goal

Measure throughput and latency for Flink jobs using OSS Apache Flink (SQL gateway, standalone cluster, or plain K8s). Same producer and job code as [../README.md](../README.md); this folder documents OSS-focused run.

## Status

Ready. Use with OSS Flink + Kafka. Producer and jobs at demo root: [../producer/](../producer/), [../flink-jobs/](../flink-jobs/), [../scripts/](../scripts/).

## Implementation approach

- **No IaC in this folder:** Use [../scripts/](../scripts/) for topics, run producer, run Flink job. Deploy OSS Flink via your own K8s or standalone.
- **Application logic:** Shared at root. Compare sql-executor, datastream, flink-sql job types.

## How to run

From **demo root**: build producer and flink-jobs, create topics (scripts), run producer, deploy/run Flink job(s), collect metrics. See root [README.md](../README.md) and [../scripts/README.md](../scripts/README.md).
