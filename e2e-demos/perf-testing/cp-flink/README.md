# Perf testing – Confluent Platform / Confluent Cloud Flink

## Goal

Measure throughput and latency for Flink jobs using Confluent Manager for Flink (CP) or Confluent Cloud for Flink. Same producer and job code as [../README.md](../README.md); this folder documents CP/CC-focused run.

## Status

Ready. Use with Confluent Platform (K8s) or Confluent Cloud. Producer and jobs at demo root: [../producer/](../producer/), [../flink-jobs/](../flink-jobs/), [../scripts/](../scripts/), [../k8s/](../k8s/).

## Implementation approach

- **K8s:** Manifests at [../k8s/](../k8s/) for CP deployment. Scripts at [../scripts/](../scripts/).
- **Application logic:** Shared at root. Deploy job via CMF or CC Flink workspace.

## How to run

From **demo root**: build producer and flink-jobs, deploy topics (scripts or k8s), run producer, deploy Flink job to CMF/CC, collect metrics. See root [README.md](../README.md).
