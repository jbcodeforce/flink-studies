# Flink to PostgreSQL sink – Confluent Platform / K8s

## Goal

Same pipeline (join topics → output topic → JDBC sink → PostgreSQL) deployed on Kubernetes with OSS Flink or Confluent Platform.

## Status

Ready. K8s manifests at [../k8s/](../k8s/) (topics, PostgreSQL, pgadmin).

## Implementation approach

- **No Terraform.** Use [../k8s/](../k8s/) and root [../start_colima.sh](../start_colima.sh) if needed.
- **Application logic:** Same as [../README.md](../README.md); deploy Flink and connector on K8s.

## How to run

From **demo root**: start Colima/K8s, apply k8s manifests, deploy Flink job and Kafka Connect JDBC sink. See [../README.md](../README.md).
