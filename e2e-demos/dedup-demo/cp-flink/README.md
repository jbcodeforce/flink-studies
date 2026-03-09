# Dedup demo – Confluent Platform Flink

## Goal

Deduplicate product events from Kafka using Flink Table API (Java), deployed on Kubernetes with FlinkApplication CRD. Same business logic as [../oss-flink/](../oss-flink/) (SQL variant).

## Status

Ready. Requires K8s with Confluent Platform. Producer: [../python-producer/](../python-producer/).

## Implementation approach

- **No Terraform:** K8s manifests in `flink-table-api/k8s/`. Makefile in `flink-table-api/` for build and deploy.
- **Application logic:** Java Table API job in `flink-table-api/`; build image, deploy via FlinkApplication.

## How to run

From **demo root** or this folder: deploy producer ([../python-producer/](../python-producer/)), then from `cp-flink/flink-table-api/`: build, deploy Flink application. See root [README.md](../README.md) and `flink-table-api/README.md`.
