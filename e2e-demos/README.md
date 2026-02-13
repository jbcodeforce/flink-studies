# A set of end-to-end demonstrations

For each demonstrations it should be easy to deploy, have a readme to explain the goals, what will be learn, how to setup and how to validate the demonstration.

All end-to-end demonstrations under `e2e-demos/`, grouped by subject. Paths are relative to `e2e-demos/`.


## 1. CDC & Change Data Capture

### 1.1 Confluent Cloud – Transaction processing (RDS → Kafka → Flink → Iceberg)

| Demo | Path | Description |
|------|------|-------------|
| **cc-cdc-tx-demo** | `https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/cc-cdc-tx-demo/` | Full Confluent Cloud demo: AWS RDS PostgreSQL → Debezium CDC → Kafka → Flink (dedup, enrichment, sliding-window aggregates) → TableFlow → Iceberg/S3, AWS Glue, Athena. ML scoring via ECS/Fargate. Outbox pattern notes. Terraform: IaC (RDS, Confluent, connectors, compute pool), cc-flink-sql/terraform (Flink statements). **Subfolders:** `cc-flink-sql/` (sources, dimensions, facts, Terraform), `data-generators/`, `IaC/`, `tx_scoring/` (ML inference service), `oubox-customer-service/` (future). |

### 1.2 Qlik CDC – Dedup & transform to analytics-ready streams

| Demo | Path | Description |
|------|------|-------------|
| **cdc-dedup-transform** | `cdc-dedup-transform/` | Qlik Replicate CDC → Flink: raw CDC envelope (key, headers, data, beforeData), filter/dedup (ROW_NUMBER), extract by operation (REFRESH/INSERT/UPDATE/DELETE), DLQ for errors, business validation, S3/Iceberg sink. Propagate DELETE to sink. IaC folder for Confluent. |

### 1.3 PostgreSQL + Debezium on Kubernetes

| Demo | Path | Description |
|------|------|-------------|
| **cdc-demo** | `cdc-demo/` | PostgreSQL (CloudNativePG) + Debezium CDC on K8s → Kafka → Flink SQL. Tables: loan_applications, transactions. Debezium envelope, `message.key.columns`, Flink DDL with debezium-json. Makefile: demo_setup, deploy_connect, demo_run, deploy_flink, flink_sql_client. Datasets and Python loaders in `datasets/`, `src/`. |

---

## 2. Deduplication

| Demo | Path | Description |
|------|------|-------------|
| **dedup-demo** | `dedup-demo/` | Two implementations: (1) **Flink SQL** (`flink-sql/`): product events from Kafka, ROW_NUMBER dedup, upsert to `src_products`; run via SQL CLI or `run-flink-dedup.sh`. (2) **Flink Table API** (`flink-table-api/`): Java app, K8s deployment (FlinkApplication CRD). Python producer (`python-producer/`) generates product events with intentional duplicates. K8s deployment with Confluent Platform. |

---

## 3. E-commerce & Streaming Analytics

### 3.1 Real-time e-commerce (purchases, inventory, recommendations)

| Demo | Path | Description |
|------|------|-------------|
| **e-com-sale** | `e-com-sale/` | Real-time e-commerce: user actions (page view, add to cart), purchases, inventory updates. Flink job from Kafka (`ecommerce.purchase` etc.): revenue per minute, top products, low-inventory alerts, behavior/conversion, simple recommendations. Python simulator, K8s topics + Flink app. Java DataStream/Table API. |

### 3.2 Flink SQL e2e (Kafka, MySQL, Elasticsearch, Kibana)

| Demo | Path | Description |
|------|------|-------------|
| **e2e-streaming-demo** | `e2e-streaming-demo/` | Flink SQL demo (Alibaba Tianchi–style user_behavior): Kafka source, TUMBLE windows (hourly buy count → Elasticsearch), cumulative UV every 10 min, top categories via temporal join to MySQL `category_dim`. Sinks: Elasticsearch, Kibana dashboards. Docker Compose. |

---

## 4. External Lookup / Enrichment

| Demo | Path | Description |
|------|------|-------------|
| **external-lookup** | `external-lookup/` | Payment events (Kafka) enriched by async lookup to external DB (claims: claim_id, claim_amount, member_id). Flink app does left join; success → `enriched-payments`, failures (invalid claim_id, DB error/timeout) → `failed-payments`. **Components:** `database/` (DuckDB + API in container, K8s), `event-generator/` (Python producer, valid/invalid claim_ids), `flink-app/` (Flink job, K8s). Colima/K8s, Confluent Platform, CMF. |

---

## 5. ML / Feature Store

| Demo | Path | Description |
|------|------|-------------|
| **flink-to-feast** | `flink-to-feast/` | Real-time windowed aggregation → Feast online feature store; ML model consumes features for inference. Confluent ML_PREDICT, connections, models. **Parts:** `feature_repo/` (Feast definitions, registry, offline store), `kafka_consumer/` (push to online store), `model_serving/` (inference). K8s manifests, Docker. |

---

## 6. Sinks & Integration

| Demo | Path | Description |
|------|------|-------------|
| **flink-to-sink-postgresql** | `flink-to-sink-postgresql/` | Flink statement joining two topics (e.g. orders + shipments) → output topic → Kafka JDBC Sink connector → PostgreSQL. Docker Compose, K8s (PostgreSQL operator, topics). Validation: data in topic and in PG. |

---

## 7. JSON Transformation & Nested Structures

| Demo | Path | Description |
|------|------|-------------|
| **json-transformation** | `json-transformation/` | Truck rental (2190): `raw-orders` + `raw-jobs` Kafka topics → Flink SQL build nested JSON `OrderDetails` (EquipmentRentalDetails, MovingHelpDetails), join orders–jobs. **Components:** `src/cc-flink/` (Confluent Cloud Flink SQL: DDL, DML, tests), `src/cp-flink/` (Confluent Platform: Table API Java, SQL, K8s FlinkApplication), `src/producer/` (FastAPI + CLI producer, Web UI), `src/schemas/` (JSON schemas). K8s under `rental` namespace, CMF, catalog, compute pool. |

---

## 8. Operational & Tooling

### 8.1 Savepoints

| Demo | Path | Description |
|------|------|-------------|
| **savepoint-demo** | `savepoint-demo/` | Stop/restart stateful Flink job with savepoints. Producer writes (sequence_id, value=2) to Kafka; Flink SQL sums value. After n records, sum = sequence_id * 2. Minikube, Confluent Platform, Python event generator, Avro schema, config.yaml. |

### 8.2 SQL Gateway

| Demo | Path | Description |
|------|------|-------------|
| **sql-gateway-demo** | `sql-gateway-demo/` | Flink SQL Gateway: start cluster and gateway, create CSV source table, deploy DML, assess results. |

### 8.3 Flink Agents (AI)

| Demo | Path | Description |
|------|------|-------------|
| **agentic-demo** | `agentic-demo/` | Flink Agents (Python): based on [Flink Agents docs](https://nightlies.apache.org/flink/flink-agents-docs-release-0.1/). Local Flink install, Python 3.11 + uv, `flink-agents` package, PYTHONPATH for JVM. |

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
| **Confluent Cloud** | `cc-cdc-tx-demo`, `json-transformation` (cc-flink), `cdc-dedup-transform` |
| **Confluent Platform / K8s** | `json-transformation`, `dedup-demo`, `external-lookup`, `cdc-demo`, `e-com-sale`, `savepoint-demo` |
| **Terraform / IaC** | `cc-cdc-tx-demo` (IaC, cc-flink-sql/terraform), `cdc-dedup-transform` (IaC) |
| **TableFlow / Iceberg** | `cc-cdc-tx-demo` |
| **Savepoints** | `savepoint-demo` |
| **SQL Gateway** | `sql-gateway-demo` |
| **Flink Agents** | `agentic-demo` |

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