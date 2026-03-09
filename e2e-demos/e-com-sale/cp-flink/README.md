# E-commerce real-time analytics – Confluent Platform Flink

## Goal

Run the e-commerce Flink job (revenue per minute, top products, low-inventory alerts, recommendations) on Confluent Platform with Confluent Manager for Flink (CMF).

## Status

Ready. Requires K8s with Confluent Platform and CMF. Simulator and Flink app at demo root.

## Implementation approach

- **No Terraform:** K8s manifests at root [../k8s/](../k8s/): use `cmf_app_deployment.yaml`, `topics.yaml`, `cm.yaml`. Root Makefile: `make build`, `make create_flink_app`, `make port-forward`.
- **Application logic:** Flink app at [../flink-app/](../flink-app/), simulator at [../simulator.py](../simulator.py).

## How to run

From the **demo root**: deploy topics (`kubectl apply -f k8s/topics.yaml`), build Flink app (`make build`), create Flink application with CMF (`make create_flink_app`), port-forward, run simulator. See root [README.md](../README.md).
