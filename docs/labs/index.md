# Local code and demonstrations, plus other public references

This section lists the current demonstrations and labs in this git repository or the interesting public repositories about Flink


## 1. Flink SQL

Under code/flink-sql folder

### 1.1 Basic SQL & Getting Started

| Sample | Path | Description |
|--------|------|-------------|
| **Basic SQL (employees, dedup, aggregation)** | [flink-sql/00-basic-sql](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/00-basic-sql/) | CSV employees demo: create table, deduplication (ROW_NUMBER), aggregation by department, streaming vs batch. Confluent Cloud: customers table, dedup, tombstone creation, snapshot query. Terraform in `cc-flink/terraform/`. |
| **OSS / local Flink** | [flink-sql/00-basic-sql/oss-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/00-basic-sql/oss-flink/) | `create_customers.sql`, `create_orders.sql` for local Flink. |

### 1.2 Kafka & Connectors

| Sample | Path | Description |
|--------|------|-------------|
| **Kafka + Flink (Docker, local, Confluent)** | [flink-sql/01-kafka-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/01-kafka-flink/) | Docker Compose (Kafka + Flink 1.20), word count from Kafka topic (`user_msgs` → `word_count`), SPLIT + UNNEST. Local Kafka + Flink binary, Confluent Cloud Kafka (TO DO). Optional Datagen connector configs in `datagen-config/`. |
| **Kafka-Flink Docker** | [flink-sql/01-kafka-flink/kafka-flink-docker](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/01-kafka-flink/kafka-flink-docker/) | `docker-compose.yaml`, Kafka config, Flink Kafka connector JARs, `starting_script.sql`. |

### 1.3 Nested Rows, Arrays & JSON

| Sample | Path | Description |
|--------|------|-------------|
| **Nested ROW, ARRAY_AGG, UNNEST** | [flink-sql/03-nested-row](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/03-nested-row/) | Nested user schema (`vw.nested_user.sql`, `dml.nested_user.sql`), ARRAY_AGG with tumbling window (`vw.array_of_rows.sql`), CROSS JOIN UNNEST. Sample `fligh_out.json`. |
| **Truck loads (last record per key from array)** | [flink-sql/03-nested-row/truck_loads](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/03-nested-row/truck_loads/) | Source with `ARRAY<ROW>`, UNNEST, upsert sink to keep last load per truck. DDL, DML, insert data. |
| **Suite / asset ARRAY_AGG** | [flink-sql/03-nested-row/cc-array-agg](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/03-nested-row/cc-array-agg/) | Aggregate asset IDs per suite with changelog (upsert). `cc_array_agg.sql`, `cc_array_agg_on_row.sql`. |
| **Healthcare CDC transformation** | [flink-sql/03-nested-row/cc-flink-health](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/03-nested-row/cc-flink-health/) | CDC JSON → flattened Member/Provider entities. Schemas, Flink SQL transforms, Python producer, Schema Registry, test data. |

### 1.4 Joins

| Sample | Path | Description |
|--------|------|-------------|
| **Joins playground (overview)** | [flink-sql/04-joins](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/) | Stream-stream joins (orders, products, shipments): left join, CTAS upsert, interval join. Order-per-minute windowing, UNNEST product_ids, avg volume per minute. Data skew (salted joins). `docker-compose.yaml`. |
| **CC stream-to-stream (orders, products, shipments)** | [flink-sql/04-joins/cc](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/cc/) | DDLs and inserts for orders, products, shipments; order–product join, CTAS joins; avg product volume per minute. |
| **Inner join with dedup (Asset / AssetType)** | [flink-sql/04-joins/cc_inner_join_with_dedup](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/cc_inner_join_with_dedup/) | Entity–entityType: ROW_NUMBER dedup on raw assets and types, inner join, ARRAY_AGG for subtype/type names. Confluent Cloud. |
| **Data skew (salted joins)** | [flink-sql/04-joins/data_skew](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/data_skew/) | Join user–group with optional salting to handle skew. DML and insert scripts. |
| **Event status processing** | [flink-sql/04-joins/event_status_processing](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/event_status_processing/) | CDC-style `event_status` (eventId, eventProcessed, eventTime). DDL and processing pattern. |
| **Group / user hierarchy** | [flink-sql/04-joins/group_users](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/group_users/) | Hierarchy in one table (e.g. hospital → department → group → person). Self-joins, ARRAY_AGG, two-level hierarchy; dim_latest_group_users with tombstone handling for group-level deletes. |
| **Rule match on sensors** | [flink-sql/04-joins/rule_match_on_sensors](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/04-joins/rule_match_on_sensors/) | Temporal join of sensor stream to static `sensor_rules` (tenant, parameter, thresholds). Faker-based sensors source. |

### 1.5 Changelog Mode (Append, Retract, Upsert)

| Sample | Path | Description |
|--------|------|-------------|
| **Changelog mode (append, retract, upsert)** | [flink-sql/05-changelog](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/05-changelog/) | Orders + products: append vs retract vs upsert. Impact on aggregation, join, dedup. CTAS for enriched_orders, user_order_quantity. Diagrams in `docs/`. Makefile for deploy/insert. |

### 1.6 Schema Evolution

| Sample | Path | Description |
|--------|------|-------------|
| **Schema refactoring (products → discounts)** | [flink-sql/07-schema-refactoring](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/07-schema-refactoring/) | PostgreSQL products table refactored: discount moved to `discounts` table. Flink join products + discounts, support old (inline discount) and new (discount_id) schema. `alter_product.sql`, `pd_discounts.sql`, `ps_products_v1.sql`. |

### 1.7 Snapshot Query & Search External Tables

| Sample | Path | Description |
|--------|------|-------------|
| **Snapshot query** | [flink-sql/08-snapshot-external-query](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/08-snapshot-external-query/) | Confluent Cloud snapshot query: Datagen connector, `SET sql.snapshot.mode = 'now'`, count on append-only table. |
| **External table lookup** | [flink-sql/08-snapshot-external-query](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/08-snapshot-external-query/) | Use KEY_SEARCH_AGG with external table deployed on AWS RDS Postgresql |

### 1.8 Temporal Joins

| Sample | Path | Description |
|--------|------|-------------|
| **Temporal joins (versioned table)** | [flink-sql/09-temporal-joins](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/09-temporal-joins/) | Join orders to versioned `currency_rates` with `FOR SYSTEM_TIME AS OF orders.order_time`. Confluent Cloud: DDLs, insert orders/rates, behavior when rates arrive late. Local: CSV + `temporal_joins.sql`. |

### 1.9 Windowing

| Sample | Path | Description |
|--------|------|-------------|
| **Tumbling & hopping windows** | [flink-sql/10-windowing](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/10-windowing/) | Tumbling window: distinct order count per minute. Hopping: 10-minute window, 5-minute slide. Uses deduplicated orders from CC marketplace. `cc-flink/create_unique_oder.sql`, `order_per_minute.sql`. |

### 1.10 Puzzles & Exercises

| Sample | Path | Description |
|--------|------|-------------|
| **SQL puzzles (overview)** | [flink-sql/11-puzzles](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/11-puzzles/) | Highest transaction per day, employees data, table DDLs. Test env: Flink binary or Kubernetes. |
| **Compute ETA (shipment)** | [flink-sql/11-puzzles/compute_eta](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/11-puzzles/compute_eta/) | ETA from shipment events: source `shipment_events`, `shipment_history` (ARRAY_AGG per shipment), join + UDF `estimate_delivery`. Confluent Cloud; Python UDF mock in `udf/`. `deploy_flink_statements.py`, Makefile. |
| **Create tables (tx, loans, employees)** | [flink-sql/11-puzzles](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/11-puzzles/) | `create_tx_table.sql`, `create_loans_table.sql`, `data/create_employees.sql`, `highest_tx_per_day.sql`. |

### 1.11 AI / ML Integration

| Sample | Path | Description |
|--------|------|-------------|
| **AI agents (anomaly detection)** | [flink-sql/12-ai-agents](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/12-ai-agents/) | Reefer temperature: Faker source, burst view, `ML_DETECT_ANOMALIES` (ARMA) in tumbling window. Confluent Flink built-in ML. |

### 1.12 SQL Execution & Runtimes

| Sample | Path | Description |
|--------|------|-------------|
| **Flink SQL Quarkus** | [flink-sql/flink-sql-quarkus](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/flink-sql-quarkus/) | Table API + SQL examples as Quarkus app. Run in IDE or submit JAR to Flink (Docker). |
| **Flink Python SQL runner** | [flink-sql/flink-python-sql-runner](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/flink-python-sql-runner/) | Python-based SQL runner entry. |
| **Triage (DDL only)** | [flink-sql/triage](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/triage/) | DDLs: `ddl.employees.sql`, `dd.departments.sql`, `ddl.jobs.sql`. |


## 2. Flink Java (DataStream API)

### 2.1 Quickstart & Word Count

| Sample | Path | Description |
|--------|------|-------------|
| **DataStream quickstart** | [flink-java/datastream-quickstart](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/datastream-quickstart/) | Minimal DataStream v2 job: `NumberMapJob`. Build, submit to Flink cluster, K8s OSS deployment YAML. |
| **Word count (file)** | [flink-java/datastream-samples/01-word-count](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/datastream-samples/01-word-count/) | Read file, count word occurrences. FileSource connector. |

### 2.2 DataStream Samples (my-flink)

| Sample | Path | Description |
|--------|------|-------------|
| **Word count, filters, joins** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) | WordCount (file), PersonFiltering, LeftOuterJoin / RightOuterJoin / FullOuterJoin / InnerJoin (persons + locations). Data in `data/`. |
| **Bank fraud** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) (bankfraud) | `Bank.java`, `BankDataServer.java`, `AlarmedCustomer.java`, `LostCard.java` – fraud/lost-card style flows. |
| **Datastream aggregations** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) (datastream) | `ComputeAggregates.java`, `ProfitAverageMR.java`, `WordCountSocketStreaming.java`. |
| **Kafka telemetry** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) (kafka) | `TelemetryAggregate.java` – Kafka source aggregation. |
| **Taxi stats** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) (taxi) | `TaxiStatistics.java`; test in `TestTaxiStatistics.java`. Data: `cab_rides.txt`, etc. |
| **Windows (sales)** | [flink-java/my-flink](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/) (windows) | `TumblingWindowOnSale.java`. Sale data server in `sale/`. |
| **Docker / K8s** | [flink-java/my-flink/src/main/docker](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/my-flink/src/main/docker/) | Dockerfile variants (JVM, legacy-jar, native). |

*Note: Some code uses deprecated DataSet API; Table API ports live under `table-api/`.*

### 2.3 Batch Processing & Table API

| Sample | Path | Description |
|--------|------|-------------|
| **Loan batch processing** | [flink-java/loan-batch-processing](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/loan-batch-processing/) | DataStream: read loan CSV, stats (avg amount, income, counts by status/type), write CSV. Table API: fraud analysis, optional DuckDB JDBC sink. `DataStreamJob.java`, `TableApiJobComplete.java`, `FraudCountTableApiJob.java`. `verify_duckdb.sh`, `query_duckdb.sql`. |

### 2.4 SQL Runner (JAR)

| Sample | Path | Description |
|--------|------|-------------|
| **SQL runner** | [flink-java/sql-runner](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/sql-runner/) | Run SQL scripts as Flink job (from Flink OSS examples). JAR with SQL in `sql-scripts/` (e.g. `main.sql`, `statement-set.sql`). Docker and K8s deployment. |

---

## 3. Table API

### 3.1 Java – Confluent Cloud

| Sample | Path | Description |
|--------|------|-------------|
| **Confluent Cloud Table API** | [table-api/ccf-table-api](https://github.com/jbcodeforce/flink-studies/tree/master/code/table-api/ccf-table-api/) | Confluent examples: catalogs, unbounded tables, transforms, table pipelines, changelogs, integration. `Example_00_HelloWorld` … `Example_08_IntegrationAndDeployment`, `TableProgramTemplate.java`. JShell init: `jshell-init.jsh`. |
| **Java Table API (Confluent)** | [table-api/java-table-api](https://github.com/jbcodeforce/flink-studies/tree/master/code/table-api/java-table-api/) | Join order–customer, deduplication, PersonLocationJoin. Env vars for CC. JShell with pre-initialized TableEnvironment. |

### 3.2 Java – OSS & Local

| Sample | Path | Description |
|--------|------|-------------|
| **OSS Table API + SQL** | [table-api/oss-table-api-with-sql](https://github.com/jbcodeforce/flink-studies/tree/master/code/table-api/oss-table-api-with-sql/) | `PersonLocationJoin` with persons/locations files. `cloud-template.properties`. |
| **Simplest local Table API** | [table-api/simplest-table-api-for-local](https://github.com/jbcodeforce/flink-studies/tree/master/code/table-api/simplest-table-api-for-local/) | In-memory table, filter, print. Session job or Application mode. |

### 3.3 Python Table API

| Sample | Path | Description |
|--------|------|-------------|
| **PyFlink** | [table-api/python-table-api](https://github.com/jbcodeforce/flink-studies/tree/master/code/table-api/python-table-api/) | `first_pyflink.py`, `word_count.py` – basic Table API in Python. |

## 4. Local end-to-end demonstrations

All the local demonstrations run on local Kubernetes, some on Confluent Cloud. Most of them are still work in progress.

See the [e2e-demos](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/README.md) folder for a set of available demos based on the Flink local deployment or using Confluent Cloud for Flink.

### 4.1 Confluent Cloud – Transaction processing (RDS → Kafka → Flink → Iceberg)

Full Confluent Cloud demo: AWS RDS PostgreSQL → Debezium CDC → Kafka → Flink (dedup, enrichment, sliding-window aggregates) → TableFlow → Iceberg/S3, AWS Glue, Athena. ML scoring via ECS/Fargate. Outbox pattern notes. Terraform: IaC (RDS, Confluent, connectors, compute pool), cc-flink-sql/terraform (Flink statements)

## Public repositories with valuable demonstrations

* [Personal Flink demo repository](https://jbcodeforce.github.io/flink_project_demos/) for Data as a product, ksql to Flink or Spark to Flink automatic migration test sets.
* [Confluent Flink how to](https://docs.confluent.io/cloud/current/flink/reference/sql-examples.html#)
* [Confluent demonstration scene](https://github.com/confluentinc/demo-scene): a lot of Kafka, Connect, and ksqlDB demos
* [Confluent developer SQL training](https://developer.confluent.io/courses/flink-sql/overview/)
* [Flink Confluent Cloud for Apache Flink Online Store Workshop](https://github.com/confluentinc/confluent-cloud-flink-workshop/blob/master/flink-getting-started/lab1.md), support Confluent enablement Tours.
* [Confluent Quick start with streaming Agents](https://github.com/confluentinc/quickstart-streaming-agents)
* [lab 3- Agentic Fleet Management Using Confluent Intelligence](https://github.com/confluentinc/quickstart-streaming-agents/blob/master/LAB3-Walkthrough.md)

* [Demonstrate Flink SQL test harness tool for Confluent Cloud Flink](https://jbcodeforce.github.io/shift_left_utils/coding/test_harness/#usage-and-recipe).

* [Shoes Store Labs](https://github.com/jbcodeforce/shoe-store)  to run demonstrations on Confluent Cloud. 
* [Confluent Cloud and Apache Flink in EC2 for Finserv workshop](https://github.com/vdeshpande-confluent/finserv-flink-workshop.git)
* [Online Retailer Stream Processing Demo using Confluent for Apache Flink](https://github.com/confluentinc/online-retailer-flink-demo)


## Interesting Blogs

* [Building Streaming Data Pipelines, Part 1: Data Exploration With Tableflow](https://www.confluent.io/blog/building-streaming-data-pipelines-part-1/)
* [Building Streaming Data Pipelines, Part 2: Data Processing and Enrichment With SQL](https://www.confluent.io/blog/streaming-etl-flink-tableflow/)

## Other related assets

* [Shift Left End to End Demonstration](https://github.com/confluentinc/online-retailer-flink-demo/blob/gko-2026/Shiftleft/README.md)