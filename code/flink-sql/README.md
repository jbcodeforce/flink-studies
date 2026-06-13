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
| `cc-flink/` (`deploy_manifest.json`, Makefile) | Complete | Confluent Cloud | `make deploy` via [cc_deploy](../tools/cc_deploy/) |
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

Standalone puzzles, the compute_eta pipeline (UDF, shipment history, ETA), and the tumble-then-hop rolling-feature study.

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
| `tumble_then_hop_rolling/README.md`, `rolling_from_hourly_buckets.sql` | Complete | Local | Manual |

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
| `cc_deploy/` (`flink_deploy.py`, `deploy_flink_statements.py`, `manifest.py`) | Complete | Confluent Cloud | Makefile + `deploy_manifest.json` per demo |
| `cc_flink_rest_client.py` | Complete | Confluent Cloud | Manual (requests REST) |
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


## Tracking refactoring of all demos

Updated 06/12/2026

Apache Flink, Confluent Plaform for Flink or Confluent Cloud SQL demos and whether they use [`tools/cc_deploy/deploy_flink_statements`](tools/cc_deploy/deploy_flink_statements.py) with [`deploy_manifest.json`](tools/README.md#demo-manifest) or other tool.

| Demo | Folder | Uses `cc_deploy.deploy_flink_statements` |
| ---- | ------ | -------------------------------------- |
| **00-basic-sql** | | |
| Employees / customers dedup | [`00-basic-sql/cc-flink`](00-basic-sql/cc-flink/) | Yes |
| Confluent Platform (schemas/topics) | [`00-basic-sql/cp-flink`](00-basic-sql/cp-flink/) | N/A |
| OSS Flink SQL | [`00-basic-sql/oss-flink`](00-basic-sql/oss-flink/) | N/A |
| **01-kafka-flink** | | |
| Kafka + Flink Docker word count | [`01-kafka-flink/kafka-flink-docker`](01-kafka-flink/kafka-flink-docker/) | N/A |
| Header propagation | [`01-kafka-flink/header_propagation`](01-kafka-flink/header_propagation/) | N/A |
| **03-nested-row** | | |
| ARRAY_AGG on rows | [`03-nested-row/cc-array-agg`](03-nested-row/cc-array-agg/) | No |
| Member / provider CDC dimensions | [`03-nested-row/cc-flink-health`](03-nested-row/cc-flink-health/) | No |
| Truck loads lookup join | [`03-nested-row/truck_loads`](03-nested-row/truck_loads/) | No |
| **04-joins** | | |
| Stream-to-stream joins (orders, products, shipments) | [`04-joins/cc`](04-joins/cc/) | Yes |
| Inner join with dedup | [`04-joins/cc_inner_join_with_dedup`](04-joins/cc_inner_join_with_dedup/) | No |
| Data skew / salted joins | [`04-joins/data_skew`](04-joins/data_skew/) | No |
| Event status processing | [`04-joins/event_status_processing`](04-joins/event_status_processing/) | No |
| Group hierarchy | [`04-joins/group_users`](04-joins/group_users/) | No |
| Rule match on sensors | [`04-joins/rule_match_on_sensors`](04-joins/rule_match_on_sensors/) | N/A — docs stub |
| **05-changelog** | | |
| Append / upsert / retract modes | [`05-changelog`](05-changelog/) | No — Confluent CLI Makefile |
| **07-schema-refactoring** | | |
| PostgreSQL CDC products / discounts | [`07-schema-refactoring`](07-schema-refactoring/) | No |
| **08-snapshot-external-query** | | |
| Snapshot via external RDS | [`08-snapshot-external-query`](08-snapshot-external-query/) | N/A — Python connector, not statement deploy |
| **09-temporal-joins** | | |
| Orders with currency rates | [`09-temporal-joins/cc`](09-temporal-joins/cc/) | No |
| Local temporal joins | [`09-temporal-joins/local-flink`](09-temporal-joins/local-flink/) | N/A |
| **10-windowing** | | |
| Orders per minute | [`10-windowing/cc-flink`](10-windowing/cc-flink/) | No |
| Grouping messages (leads) | [`10-windowing/grouping_messages/cc-flink`](10-windowing/grouping_messages/cc-flink/) | No — Terraform |
| Tumble-then-hop rolling features | [`10-windowing/tumble_then_hop_rolling`](10-windowing/tumble_then_hop_rolling/) | Yes |
| **11-puzzles** | | |
| Cart update (integrated cart) | [`11-puzzles/cart_update`](11-puzzles/cart_update/) | Yes |
| Compute ETA (shipments + UDF) | `11-puzzles/compute_eta/` | No — legacy per-demo script (folder not in repo) |
| Local SQL puzzles | [`11-puzzles`](11-puzzles/) (root `.sql` files) | N/A |
| **12-ai-agents** | | |
| ML anomaly detection (docs) | [`12-ai-agents`](12-ai-agents/) | N/A |
| **13-materialized-table** | | |
| Materialized table (local OSS) | [`13-materialized-table`](13-materialized-table/) | N/A |

**Summary:** 4 demos migrated (`Yes`), 14 Confluent Cloud candidates still on manual / Confluent CLI / Terraform (`No`).