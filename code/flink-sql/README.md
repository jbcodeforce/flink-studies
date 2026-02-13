# Flink SQL

Flink SQL examples and tutorials: basic patterns, Kafka integration, changelog modes, joins, windowing, and puzzles. This README tracks assets developed from this folder.

**Table columns:**

- **Asset** — Name or path of the artifact (SQL, config, script, app).
- **Code completion** — Implementation state: `Complete`, `Partial`, or `Stub/Docs`.
- **Deployment status** — Where it runs: `Local`, `Docker`, `Confluent Cloud`, `Terraform`, `Manual`, or combination.
- **Automation** — How it is run or deployed: `Makefile`, Python/script, Confluent CLI, or `Manual`.

---

## 00-basic-sql

Basic Flink SQL (employees per department). Runs on local Flink OSS, Confluent Platform on Kubernetes, or Confluent Cloud.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `cc-flink/ddl.customers.sql` | Complete | Confluent Cloud | Manual / Terraform |
| `cc-flink/dml.dedup_customers.sql` | Complete | Confluent Cloud | Manual / Terraform |
| `cc-flink/insert_customers.sql` | Complete | Confluent Cloud | Manual |
| `cc-flink/terraform/` | Complete | Confluent Cloud | Terraform |
| `oss-flink/create_customers.sql` | Complete | Local | Manual |
| `oss-flink/create_orders.sql` | Complete | Local | Manual |

---

## 01-kafka-flink

Flink with Kafka: word count and message processing. Docker Compose (Kafka + Flink) or local binaries.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `kafka-flink-docker/docker-compose.yaml` | Complete | Docker | Manual |
| `kafka-flink-docker/connectors/` (Kafka connector JARs) | Complete | Docker | Manual |
| `starting_script.sql` | Complete | Docker / Local | Manual |
| `datagen-config/*.json` | Complete | Kafka Connect | curl / Manual |

---

## 03-nested-row

Nested rows, ARRAY_AGG, and CDC-style pipelines (member/provider dimensions, truck loads).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `cc-array-agg/cc_array_agg.sql` | Complete | Confluent Cloud | Manual |
| `cc-array-agg/cc_array_agg_on_row.sql` | Complete | Confluent Cloud | Manual |
| `cc-flink-health/sql/*.sql` (member/provider DDL/DML) | Complete | Confluent Cloud | Manual |
| `cc-flink-health/producer/*.py` | Complete | Local | Manual |
| `truck_loads/ddl.*.sql`, `dml.*.sql`, `insert_*.sql` | Complete | Confluent Cloud / Local | Manual |
| `vw.nested_user.sql`, `vw.array_of_rows.sql` | Complete | Local / Confluent Cloud | Manual |
| `dml.nested_user.sql` | Complete | Local / Confluent Cloud | Manual |

---

## 04-joins

Stream-to-stream and dimension joins, group hierarchy, data skew, event status.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `cc/cc_s2s_*.sql`, `cc.customer_orders.sql`, `cc-3-avg-*.sql` | Complete | Confluent Cloud | Makefile (includes `common.mk`) |
| `cc/Makefile` | Complete | Confluent Cloud | Confluent CLI |
| `cc_inner_join_with_dedup/*.sql` | Complete | Confluent Cloud | Manual |
| `data_skew/*.sql` | Complete | Local / Confluent Cloud | Manual |
| `group_users/*.sql` | Complete | Confluent Cloud | Manual |
| `event_status_processing/ddl.event_status.sql` | Complete | Confluent Cloud | Manual |
| `rule_match_on_sensors/` | Stub/Docs | — | — |
| `docker-compose.yaml` | Complete | Docker | Manual |

---

## 05-changelog

Changelog modes: append, upsert, retract. Orders/products pipeline and CTAS examples.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `ddl.orders-append-mode.sql`, `ddl.orders-retract-mode.sql`, `ddl.orders-upsert-mode.sql` | Complete | Confluent Cloud | Makefile |
| `ddl.products-append-mode.sql` | Complete | Confluent Cloud | Makefile |
| `dml.insert-basic-orders.sql`, `dml.insert-products.sql` | Complete | Confluent Cloud | Makefile |
| `ctas.enriched_orders.sql`, `ctas.user-order-quantity-*.sql` | Complete | Confluent Cloud | Makefile |
| `Makefile` | Complete | Confluent Cloud | Confluent CLI (create/delete statements) |

---

## 07-schema-refactoring

Schema evolution: PostgreSQL → CDC → Flink data product (products, discounts).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `ps_products_v1.sql` | Complete | Confluent Cloud / Local | Manual |
| `pd_discounts.sql` | Complete | Confluent Cloud / Local | Manual |
| `alter_product.sql` | Complete | Confluent Cloud / Local | Manual |

---

## 08-snapshot-query

Snapshot query demo using Datagen connector and Flink UI.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `readme.md` (snapshot mode + query steps) | Complete | Confluent Cloud (UI) | Manual (Connector UI + Query editor) |

---

## 09-temporal-joins

Temporal joins (orders with currency rates). Confluent Cloud and local Flink.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `cc/ddl.orders.sql`, `ddl.currency_rates.sql`, `ddl.orders_with_curr_rate.sql` | Complete | Confluent Cloud | Manual |
| `cc/dml.temp_join.sql` | Complete | Confluent Cloud | Manual |
| `cc/insert_*.sql` | Complete | Confluent Cloud | Manual |
| `local-flink/temporal_joins.sql` | Complete | Local | Manual |
| `local-flink/start_sql_client.sh` | Complete | Local | Manual |

---

## 10-windowing

Windowing examples (e.g. orders per minute).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `cc-flink/create_unique_oder.sql` | Complete | Confluent Cloud | Manual |
| `cc-flink/order_per_minute.sql` | Complete | Confluent Cloud | Manual |

---

## 11-puzzles

Standalone puzzles and the compute_eta pipeline (UDF, shipment history, ETA).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `compute_eta/ddl.shipments_table.sql`, `ddl.shipment_history.sql` | Complete | Confluent Cloud | Makefile + Python |
| `compute_eta/dml.shipment_history.sql`, `dml.compute_eta.sql` | Complete | Confluent Cloud | Makefile + Python |
| `compute_eta/confluent/*.sql` | Complete | Confluent Cloud | Makefile + Python |
| `compute_eta/deploy_flink_statements.py` | Complete | Confluent Cloud | Makefile (`deploy` / `undeploy`) |
| `compute_eta/Makefile` | Complete | Confluent Cloud | Confluent CLI / Python |
| `compute_eta/eta_udf/` (Python UDF) | Complete | Confluent Cloud / Local | Manual |
| `create_tx_table.sql`, `create_loans_table.sql` | Complete | Local | Manual |
| `highest_tx_per_day.sql` | Complete | Local | Manual |
| `data/create_employees.sql`, `employees.csv` | Complete | Local | Manual |
| `flink_sql_client.yaml`, `hostpath-*.yaml` | Complete | Kubernetes / Local | Manual |

---

## 12-ai-agents

AI/ML agents and Flink (e.g. anomaly detection). Documentation and reference assets.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `README.md` | Stub/Docs | — | — |
| `images/ml_anomaly_results.png` | Complete | — | — |

---

## tools

Utilities for wide-table generation and Flink SQL.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `flink_wide_table.sql` | Complete | Local / Confluent Cloud | Manual |
| `gen_flink_wide_table.py` | Complete | Local | Manual |

---

## triage

Ad-hoc DDL and reference SQL (employees, departments, jobs).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `ddl.employees.sql` | Complete | Local | Manual |
| `dd.departments.sql` | Complete | Local | Manual |
| `ddl.jobs.sql` | Complete | Local | Manual |

---

## flink-python-sql-runner

Runner image for executing Flink SQL with Python.

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `Dockerfile` | Complete | Docker | Manual |

---

## flink-sql-quarkus

Quarkus app integrating Flink SQL (Table API / Java).

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| Java sources, `application.properties` | Complete | Local / Container | Maven / Manual |

---

## Shared

| Asset | Code completion | Deployment status | Automation |
|-------|------------------|-------------------|------------|
| `common.mk` | Complete | Confluent Cloud | Used by 04-joins/cc, 05-changelog Makefiles |
| `data/*.csv`, `data/cab_rides.txt` | Complete | — | — |
