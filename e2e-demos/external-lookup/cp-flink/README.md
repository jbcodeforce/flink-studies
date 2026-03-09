# External lookup – Confluent Platform Flink

## Goal

Enrich payment events (Kafka) with claim metadata via async lookup to an external DB. Flink job does left join; success → enriched-payments, failures → failed-payments. Demonstrates lookup failure handling (invalid claim_id, DB timeout).

## Status

Ready. Requires Colima/K8s with Confluent Platform and Confluent Manager for Flink. Shared: [../database/](../database/) (DuckDB + API), [../event-generator/](../event-generator/) (producer).

## Implementation approach

- **No Terraform:** K8s manifests in `k8s/` (topics, compute pool, catalog). Root Makefile: `make prepare_demo`, `make run_demo`.
- **Application logic:** Flink app in `flink-app/` (build/deploy via Makefile). Database and event-generator at demo root.

## How to run

From the **demo root**:

1. Prerequisites: Colima, Confluent Platform, CMF (see [../../deployment/k8s/](../../deployment/k8s/)). Run `make start_colima` if needed.
2. `make prepare_demo` – Deploy DB, event-generator, Flink app, topics, catalog.
3. `make run_demo` – Run the narrative/demo.

See root [README.md](../README.md) for full flow and architecture.
