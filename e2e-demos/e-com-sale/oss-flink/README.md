# E-commerce real-time analytics – OSS Flink

## Goal

Run the same e-commerce Flink job on plain Kubernetes with OSS Flink (no Confluent Manager).

## Status

Ready. Requires K8s with Kafka and OSS Flink. Simulator and Flink app at demo root.

## Implementation approach

- **No Terraform:** K8s manifests at root [../k8s/](../k8s/): use `oss_app_deployment.yaml`, `topics.yaml`, `cm.yaml`.
- **Application logic:** Same [../flink-app/](../flink-app/) and [../simulator.py](../simulator.py) as CP variant.

## How to run

From the **demo root**: deploy topics, deploy OSS Flink app (`kubectl apply -f k8s/oss_app_deployment.yaml`), run simulator. See root [README.md](../README.md).
