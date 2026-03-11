# Last Flink News

???- info "Updates"
    - Created 03/11/2026

## Updates to this web site

### Documentation

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

### E2E Demos — Restructure and Confluent Cloud

- **Layout**
    - Demo skill added; demos restructured with consistent **cccloud** / **cp-flink** / **oss-flink** (and sometimes **cccloud/IaC**) layout across:  `cc-cdc-tx-demo`, `cdc-dedup-transform`, `cdc-demo`, `dedup-demo`, `e-com-sale`, `e2e-streaming-demo`, `external-lookup`, `flink-to-feast`, `flink-to-sink-postgresql`, `json-transformation`, `package-event-cutoff`, `perf-testing`, `savepoint-demo`, `sql-gateway-demo`.
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
    - tool for Confluent cloud REST client with runDDL, and runDml functions to simplify demonstration deployment
    - Bulk NDJSON message generator; delete functions in generate-data code; tool to generate big table.
    - Finalized windowing queries; array_agg example; Entity → EntityType enrichment with dedup and array_agg.

### Table API & Java

- **Table API**
    - New/updated Table API content: `ccf-table-api` README, examples (HelloWorld, Catalogs, UnboundedTables, TransformingTables, CreatingTables, Pipelines, Values/DataTypes, Changelogs, Integration/Deployment), `TableProgramTemplate`.
    - Removed legacy `java-table-api` (JShell, old examples) and `loan-batch-processing`; consolidated under `ccf-table-api` and examples.
    - `set_confluent_env` script; dependency-reduced POMs and pom updates.
- **CDC Table API job**
    - `CdcToSilverTableJob` (Java) in cdc-tableapi-to-silver: table-api-java variant and cccloud test/validation tooling.
- **Deployment**
    - `deployment/product-tar/install-flink-local.sh` tweak; TableFlow moved with Flink deployment.


### Infrastructure & Deployment

- **Terraform**
    - Confluent Cloud Terraform for new env; Flink Terraform; cc-cdc-tx-demo and package-event-cutoff IaC under `cccloud/IaC`.
    - Variables, outputs, providers, TableFlow/connectors/Confluent resources where applicable.
- **Kubernetes**
    - K8s deployment updates (Confluent Platform, CMF 2.4); configs for Flink, K Connect, Debezium, PostgreSQL, namespaces, RBAC, topics, schemas.
- **Confluent Cloud**
    - Finalize CC and OSS paths for 00-sql code; Confluent Cloud Flink statements and deployment docs.

### Cookbook & Operations

- **Cookbook**
    - New cookbook: introduction, considerations, cluster management, job lifecycle, FKO & CMF deployment, Confluent Cloud Terraform, monitoring.
- **Disaster recovery**
    - DR diagram and cluster management (including DR) documentation.

### Other

- **Agentic / AI**
    - Agentic EDA updates; AI agent SQL for anomaly detection; some AI agents content.
- **DBT**
    - dbt notes, code, and chapter updates.
- **Performance**
    - Perf-testing chapter and code; perf-testing demo with cp-flink and oss-flink READMEs.
- **Misc**
    - Typos; query profiler and nginx Makefile; schema registry client; database additions for demos.

---

## Apache Flink News

### Apache Flink Kubernetes Operator 1.14.0 Release Announcement
**February 15, 2026** — Sergio Chong Loo / Daniel Rossos

- First major 2026 release of the Flink Kubernetes Operator.
- **Highlight:** Native **Blue/Green deployment** support for production.
- Enables deploying stateful streaming applications without downtime via automated Blue/Green deployments on Kubernetes.
- [Continue reading →](https://flink.apache.org/2026/02/15/apache-flink-kubernetes-operator-1.14.0-release-announcement/)

### Apache Flink Agents 0.2.0 Release Announcement
**February 6, 2026** — Xintong Song

- Second release of the Flink Agents sub-project.
- **Preview version:** APIs and config may change; some known/unknown issues possible (tracked on GitHub Issues).
- Download and documentation/quickstart are available.
- [Continue reading →](https://flink.apache.org/2026/02/06/apache-flink-agents-0.2.0-release-announcement/)


### Apache Flink 2.2.0: Advancing Real-Time Data + AI
**December 4, 2025** — Hang Ruan

- Major release focusing on **real-time data + AI** and stream processing for the “AI era.”
- **73 contributors**, **9 FLIPs** implemented, **220+ issues** resolved.
- **New/improved:** AI capabilities, materialized tables, Connector framework, batch processing, PyFlink.
- **Notable features:** **ML_PREDICT** (LLM inference), **VECTOR_SEARCH** (real-time vector similarity search) for streaming AI apps.
- [Continue reading →](https://flink.apache.org/2025/12/04/apache-flink-2.2.0-advancing-real-time-data--ai-and-empowering-stream-processing-for-the-ai-era/)

### From Stream to Lakehouse: Kafka Ingestion with the Flink Dynamic Iceberg Sink
**November 11, 2025** — Swapna Marru

- Describes the **Flink Dynamic Iceberg Sink** pattern for ingesting many evolving Kafka topics into a lakehouse.
- Addresses complex, brittle pipelines and manual changes when write patterns evolve.
- **Capabilities:** Write streaming data into multiple Iceberg tables dynamically, with schema evolution and zero-downtime adaptation; create and write to new tables based on instructions in the records.
- [Continue reading →](https://flink.apache.org/2025/11/11/from-stream-to-lakehouse-kafka-ingestion-with-the-flink-dynamic-iceberg-sink/)


## Confluent Flink News

Confluent has integrated AI as a "first-class citizen" within Flink SQL, allowing developers to build AI-driven applications without leaving the data stream.

* **Flink Native Inference:** You can now run open-source AI models (like Meta Llama) directly within Confluent Cloud. This reduces latency and keeps data secure by avoiding calls to external third-party APIs.
* **Streaming Agents:** A framework to build and orchestrate event-driven AI agents. These agents "live" in the event stream, allowing them to observe, decide, and act in real-time with the freshest business context.
* **Flink Search (Vector Database Integration):** A unified interface to perform vector searches across databases like MongoDB, Elasticsearch, and Pinecone directly from Flink SQL.
* **Remote Model Support:** Support for external providers like Anthropic and Fireworks AI was added in early 2026, expanding the options for model inference.
* **Built-in ML Functions:** New functions for forecasting and anomaly detection are available natively in Flink SQL, making advanced data science accessible to non-specialists.
* **Snapshot Queries:** Introduced in Q2 2025, this feature allows you to run fast, batch-style queries across Kafka topics and Tableflow data (Iceberg/Delta Lake). It is optimized for interactive speed (up to 50-100x faster than traditional streaming jobs for historical data), which is ideal for debugging and data exploration.
* **Tableflow Integration:** Flink now works seamlessly with Tableflow to treat streaming Kafka topics as analytical tables (Iceberg/Delta Lake) with support for upserts and Dead Letter Queues (DLQ).
* **Python UDFs (User-Defined Functions):** Developers can now write scalar UDFs in Python and run them directly within Flink SQL. This opens up Flink to Python's massive ecosystem of ML and data libraries.
* **Flink SQL Query Profiler:** A dynamic visual dashboard that helps identify performance bottlenecks by providing real-time metrics across statements, tasks, and operators.
* **Custom Error Handling:** You can now define how Flink handles deserialization errors (e.g., ignoring bad records or routing them to a Dead Letter Queue table) to keep pipelines running smoothly.
* **Improved Watermark Strategy:** The default watermark strategy (SOURCE_WATERMARK()) was updated to a fixed tolerance of 180ms. It now produces watermarks immediately without requiring a minimum record count, preventing "stuck" queries in low-traffic partitions.
* **Progressive Idleness Detection:** Idle timeouts were reduced (from 15s to 10s), and idle partitions now forward their latest event time, ensuring that one quiet partition doesn't block the results of a multi-partition query.
* **Vector Search on External DBs:** Specifically, similarity search support for Azure Cosmos DB was added in early 2026 for RAG