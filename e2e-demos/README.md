# A set of end-to-end demonstrations

For each demonstration it should be easy to deploy, have a readme to explain the goals, what will be learned, how to setup and how to validate.

All end-to-end demonstrations under `e2e-demos/`, grouped by subject. Paths are relative to `e2e-demos/`.

**Standard layout:** Demos may expose deployment-specific folders: **`cccloud/`** (Confluent Cloud + Terraform), **`cp-flink/`** (Confluent Platform Flink on K8s), **`oss-flink/`** (OSS Apache Flink). Each has a README with goal, status, implementation approach, and how to run. See [.cursor/skills/e2e-demo-structure/SKILL.md](../.cursor/skills/e2e-demo-structure/SKILL.md).


## 1. CDC & Change Data Capture

### 1.1 Confluent Cloud – Transaction processing (RDS → Kafka → Flink → Iceberg)

| Demo | Path | Description |
|------|------|-------------|
| **cc-cdc-tx-demo** | `cc-cdc-tx-demo/` | Full Confluent Cloud demo: AWS RDS PostgreSQL → Debezium CDC → Kafka → Flink (dedup, enrichment, sliding-window aggregates) → TableFlow → Iceberg/S3, AWS Glue, Athena. ML scoring via ECS/Fargate. **Deployment:** `cccloud/IaC/` (Terraform), `cccloud/cc-flink-sql/` (Flink statements). Root: `data-generators/`, `tx_scoring/`. |

### 1.2 Qlik CDC – Dedup & transform to analytics-ready streams

| Demo | Path | Description |
|------|------|-------------|
| **cdc-dedup-transform** | `cdc-dedup-transform/` | Qlik Replicate CDC → Flink: raw CDC envelope, filter/dedup, DLQ, business validation, S3/Iceberg sink. **Deployment:** `cccloud/IaC/`, `cccloud/customers/`, `cccloud/raw_topic_for_tests/`. |

### 1.3 PostgreSQL + Debezium on Kubernetes

| Demo | Path | Description |
|------|------|-------------|
| **cdc-demo** | `cdc-demo/` | PostgreSQL (CloudNativePG) + Debezium CDC on K8s → Kafka → Flink SQL. **Deployment:** `cp-flink/` (infrastructure, src). Root Makefile. Datasets at root. |

### 1.4 Debezium mock – Table API to silver (dimensions and facts)

| Demo | Path | Description |
|------|------|-------------|
| **cdc-tableapi-to-silver** | `cdc-tableapi-to-silver/` | Mock Debezium envelope → silver → dim_account, fct_transactions. Red/green TDD with run_tests.sh. **Deployment:** `cccloud/`, `oss-flink/`. Shared: sources/, dimensions/, facts/. |

---

## 2. Deduplication

| Demo | Path | Description |
|------|------|-------------|
| **dedup-demo** | `dedup-demo/` | Dedup product events: **oss-flink/** (Flink SQL), **cp-flink/** (Table API Java, K8s). Producer: `python-producer/`. |

---

## 3. E-commerce & Streaming Analytics

### 3.1 Real-time e-commerce (purchases, inventory, recommendations)

| Demo | Path | Description |
|------|------|-------------|
| **e-com-sale** | `e-com-sale/` | Real-time e-commerce analytics. **Deployment:** `cp-flink/` (CMF), `oss-flink/` (OSS). Shared: flink-app/, k8s/, simulator.py. |

### 3.2 Flink SQL e2e (Kafka, MySQL, Elasticsearch, Kibana)

| Demo | Path | Description |
|------|------|-------------|
| **e2e-streaming-demo** | `e2e-streaming-demo/` | Flink SQL (user_behavior): TUMBLE windows, cumulative UV, top categories. **Deployment:** `oss-flink/`. Docker Compose. |

---

## 4. External Lookup / Enrichment

| Demo | Path | Description |
|------|------|-------------|
| **external-lookup** | `external-lookup/` | Payment events enriched by lookup to external DB; success → enriched-payments, failures → failed-payments. **Deployment:** `cp-flink/` (flink-app, k8s). Shared: database/, event-generator/. |

---

## 5. ML / Feature Store

| Demo | Path | Description |
|------|------|-------------|
| **flink-to-feast** | `flink-to-feast/` | Windowed aggregation → Feast online store; ML inference. **Deployment:** `cccloud/`. Shared: feature_repo/, kafka_consumer/, model_serving/, k8s/. |

---

## 6. Sinks & Integration

| Demo | Path | Description |
|------|------|-------------|
| **flink-to-sink-postgresql** | `flink-to-sink-postgresql/` | Join two topics → output topic → JDBC Sink → PostgreSQL. **Deployment:** `oss-flink/` (Docker Compose), `cp-flink/` (K8s). |

---

## 7. JSON Transformation & Nested Structures

| Demo | Path | Description |
|------|------|-------------|
| **json-transformation** | `json-transformation/` | Truck rental: raw-orders + raw-jobs → nested OrderDetails (join). **Deployment:** `cccloud/` (Flink SQL), `cp-flink/` (Table API Java, K8s). Shared: src/producer/, src/schemas/. |

---

## 8. Operational & Tooling

### 8.1 Savepoints

| Demo | Path | Description |
|------|------|-------------|
| **savepoint-demo** | `savepoint-demo/` | Stop/restart stateful Flink job with savepoints. **Deployment:** `cp-flink/`. Minikube, Confluent Platform. |

### 8.2 SQL Gateway

| Demo | Path | Description |
|------|------|-------------|
| **sql-gateway-demo** | `sql-gateway-demo/` | Flink SQL Gateway: start cluster and gateway, CSV source, DML. **Deployment:** `oss-flink/` (local). |

### 8.3 Flink Agents (AI)

| Demo | Path | Description |
|------|------|-------------|
| **agentic-demo** | `agentic-demo/` | Flink Agents (Python). **Deployment:** `oss-flink/` (local Flink). Python 3.11 + uv, flink-agents. |

---

## 9. Time-based triggers / Cutoff

| Demo | Path | Description |
|------|------|-------------|
| **package-event-cutoff** | `package-event-cutoff/` | Package morning cutoff (11:30): pass-through + proactive emit for no-event packages; ETA computation with UDF. **Deployment:** `cccloud/` (IaC, run_use_case_*.sh). Shared: sql-scripts/, tests/, eta_udf/. |

---

## Quick Reference by Topic

| Topic | Demos |
|-------|--------|
| **CDC (Debezium)** | `cc-cdc-tx-demo`, `cdc-demo` |
| **CDC (Qlik / custom envelope)** | `cdc-dedup-transform` |
| **Deduplication** | `dedup-demo`, `cdc-dedup-transform`, `cc-cdc-tx-demo` |
| **Enrichment / joins** | `cc-cdc-tx-demo`, `json-transformation`, `external-lookup`, `e2e-streaming-demo` |
| **Windowing / aggregation** | `cc-cdc-tx-demo`, `e2e-streaming-demo`, `e-com-sale`, `flink-to-feast` |
| **JSON / nested** | `json-transformation` |
| **External DB lookup** | `external-lookup`, `e2e-streaming-demo` (JDBC temporal) |
| **ML / feature store** | `flink-to-feast`, `cc-cdc-tx-demo` (tx_scoring) |
| **Sink to RDBMS** | `flink-to-sink-postgresql` |
| **Confluent Cloud** | `cc-cdc-tx-demo` (cccloud/), `json-transformation` (cccloud/), `cdc-dedup-transform` (cccloud/), `package-event-cutoff` (cccloud/) |
| **Confluent Platform / K8s** | `json-transformation` (cp-flink/), `dedup-demo` (cp-flink/), `external-lookup` (cp-flink/), `cdc-demo` (cp-flink/), `e-com-sale` (cp-flink/), `savepoint-demo` (cp-flink/) |
| **OSS Flink** | `dedup-demo` (oss-flink/), `e-com-sale` (oss-flink/), `perf-testing` (oss-flink/), `cdc-tableapi-to-silver` (oss-flink/), `flink-to-sink-postgresql` (oss-flink/), `e2e-streaming-demo` (oss-flink/), `sql-gateway-demo` (oss-flink/), `agentic-demo` (oss-flink/) |
| **Terraform / IaC** | `cc-cdc-tx-demo` (cccloud/IaC), `cdc-dedup-transform` (cccloud/IaC), `package-event-cutoff` (cccloud/IaC) |
| **TableFlow / Iceberg** | `cc-cdc-tx-demo` |
| **Savepoints** | `savepoint-demo` |
| **SQL Gateway** | `sql-gateway-demo` |
| **Flink Agents** | `agentic-demo` |
| **Time-based cutoff / proactive events** | `package-event-cutoff` |

---

## CP-Flink Demonstrations

### Tracking
| Name | Readme | Make | Demo Script | Status |
|------|--------|------|--------|--------|
| json-transform | Yes | | | 

### Proof of concept for QLik CDC processing with Confluent Cloud Flink

[Detailed Readme](./cdc-dedup-transform/)

### Json Transformation

* [Readme](./json-transformation/README.md)
* [To Do](./json-transformation/checklist.md)

## CC-flink Demonstrations

* [cc-cdc-tx-demo](./cc-cdc-tx-demo/README.md) CDC from Postgresql tables, Debezium envelop processing, deduplication, delete operation propagation, statefule windowing processing. Finance Domain: customer, transaction. Terraform deployment: RDS, kafka cluster, connectors, compute pool, S3, Redshift.