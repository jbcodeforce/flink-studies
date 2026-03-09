# Savepoint demo – Confluent Platform

## Goal

Stop and restart a stateful Flink job with savepoints. Producer writes to Kafka; Flink SQL sums values. Minikube, Confluent Platform. See root [../readme.md](../readme.md).

## Status

Ready. Confluent Platform on Minikube; Python event generator, Avro schema at root.

## Implementation approach

- **No Terraform.** K8s/manifests and config at root ([../config.yaml](../config.yaml), [../orders-topic.yaml](../orders-topic.yaml), etc.).
- **Application logic:** Event generator and Flink job at root.

## How to run

From **demo root**: deploy Confluent Platform (Minikube), create topic, run event generator, deploy Flink job, trigger savepoint and restore. See [../readme.md](../readme.md).
