# Flink Studies Repository — Changelog Summary

Summary of recent changes from the git history (219 commits since 2024; latest March 2026).

---

## Documentation

- **Labs & navigation**
  - Updated labs index and readme; improved diagram and readme navigation.
  - Restructured docs: architecture content moved into concepts; added cookbook section.
- **Concepts**
  - Star schema, data skew (with SQL examples), temporal joins, DQL updates.
  - SQL content structure and temporal-join examples; group-user and hierarchy demos.
- **Coding guides**
  - Table API doc overhaul; Table API execution (SQL and Confluent Cloud) with screenshots.
  - DataStream first program, SQL clients, create table / DML, UDFs & PTFs.
  - dbt chapter and notes; SQL and UDF notes; schema how-to comments.
- **Deployment & operations**
  - Confluent Cloud Flink SQL deployment; CP Flink deployment; cluster management (DR) doc.
  - Kubernetes deployment (CCC 2.4, new CMF); FKO & CMF deployment; Terraform content and Confluent Cloud Terraform.
- **Methodology & architecture**
  - Data-as-a-product chapter; agentic EDA; AI agent SQL for anomaly detection.
  - TableFlow with Flink deployment; disaster recovery diagram.

---

## E2E Demos — Restructure and Confluent Cloud

- **Layout**
  - Demo skill added; demos restructured with consistent **cccloud** / **cp-flink** / **oss-flink** (and sometimes **cccloud/IaC**) layout across:
    - `cc-cdc-tx-demo`, `cdc-dedup-transform`, `cdc-demo`, `dedup-demo`, `e-com-sale`, `e2e-streaming-demo`, `external-lookup`, `flink-to-feast`, `flink-to-sink-postgresql`, `json-transformation`, `package-event-cutoff`, `perf-testing`, `savepoint-demo`, `sql-gateway-demo`.
  - Many demos now have `cccloud/README.md`, `cp-flink/README.md`, and/or `oss-flink/README.md`.
- **CDC**
  - **cdc-tableapi-to-silver**: Table API + CDC path; Confluent Cloud automation (`cc_deploy_raw_data`, `cc_run_validate_tests`, `cc_clean_all`), validation SQL and test definitions under `cccloud/`; Java Table API job; screenshots and README updates.
  - **cc-cdc-tx-demo**: Flink statements aligned with Shift Left structure + Terraform; IaC and cc-flink-sql moved under `cccloud/`; MQTA staging DDL/DML and migration notes; screenshots and notes.
  - **cdc-demo**: CDC lab updates; `cp-flink/` layout with infrastructure (Debezium, K Connect, Flink, PostgreSQL) and Python data generators.
  - **cdc-dedup-transform**: IaC under `cccloud/IaC`; cccloud README.
- **Other demos**
  - **package-event-cutoff**: Cutoff demo completed; package-event readme and use-case scripts; ETA UDF; port forwarding in bootstrap for local producer; `cccloud/IaC` and cleanup script.
  - **external-lookup**: Confluent Cloud Terraform for new env; external table lookup from Flink; `cp-flink` layout (flink-app, k8s, CMF).
  - **flink-to-feast**: Flink-to-Feast demo and cccloud README.
  - **json-transformation**: Folder refactor; `src/cc-flink` → `cccloud` and `cp-flink`; Table API rental example; CMF 2.1.
  - **dedup-demo**: `cp-flink` and `oss-flink` layout (flink-table-api, flink-sql).
  - **savepoint-demo**: cp-flink README and readme updates.
- **Code & tools**
  - 00-basic-sql Confluent Cloud employees demo and REST client updates.
  - Bulk NDJSON message generator; delete functions in generate-data code; tool to generate big table.
  - Finalized windowing queries; array_agg example; Entity → EntityType enrichment with dedup and array_agg.

---

## Table API & Java

- **Table API**
  - New/updated Table API content: `ccf-table-api` README, examples (HelloWorld, Catalogs, UnboundedTables, TransformingTables, CreatingTables, Pipelines, Values/DataTypes, Changelogs, Integration/Deployment), `TableProgramTemplate`.
  - Removed legacy `java-table-api` (JShell, old examples) and `loan-batch-processing`; consolidated under `ccf-table-api` and examples.
  - `set_confluent_env` script; dependency-reduced POMs and pom updates.
- **CDC Table API job**
  - `CdcToSilverTableJob` (Java) in cdc-tableapi-to-silver: table-api-java variant and cccloud test/validation tooling.
- **Deployment**
  - `deployment/product-tar/install-flink-local.sh` tweak; TableFlow moved with Flink deployment.

---

## Infrastructure & Deployment

- **Terraform**
  - Confluent Cloud Terraform for new env; Flink Terraform; cc-cdc-tx-demo and package-event-cutoff IaC under `cccloud/IaC`.
  - Variables, outputs, providers, TableFlow/connectors/Confluent resources where applicable.
- **Kubernetes**
  - K8s deployment updates (Confluent Platform, CMF 2.4); configs for Flink, K Connect, Debezium, PostgreSQL, namespaces, RBAC, topics, schemas.
- **Confluent Cloud**
  - Finalize CC and OSS paths for 00-sql code; Confluent Cloud Flink statements and deployment docs.

---

## Cookbook & Operations

- **Cookbook**
  - New cookbook: introduction, considerations, cluster management, job lifecycle, FKO & CMF deployment, Confluent Cloud Terraform, monitoring.
- **Disaster recovery**
  - DR diagram and cluster management (including DR) documentation.

---

## Other

- **Agentic / AI**
  - Agentic EDA updates; AI agent SQL for anomaly detection; some AI agents content.
- **DBT**
  - dbt notes, code, and chapter updates.
- **Performance**
  - Perf-testing chapter and code; perf-testing demo with cp-flink and oss-flink READMEs.
- **Misc**
  - Typos; query profiler and nginx Makefile; schema registry client; database additions for demos.

---

## Quick stats (recent commits)

| Area              | Notable changes |
|-------------------|------------------|
| **Docs**          | Labs index, Table API, cookbook, concepts (star schema, data skew), dbt, DR, deployment |
| **E2E demos**     | cccloud/cp-flink/oss-flink layout; CDC Table API to Silver; cutoff; cc-cdc-tx; package-event; external lookup; json-transform |
| **Table API**     | ccf-table-api examples; Java CDC job; remove legacy java-table-api |
| **Infra**         | Terraform (CC, Flink); K8s/CMF 2.4; IaC under cccloud |
| **Methodology**   | Data-as-a-product; agentic EDA; AI agent SQL |

*Generated from git history; for exact commit details run `git log --oneline` in the repository.*
