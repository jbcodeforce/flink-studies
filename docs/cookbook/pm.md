---
title: "Flink Project Management"
source: flink-studies/docs/cookbook/pm.md
ingested:
tags: [flink, cookbook]
type: article
compiled: false
---
???- info "Version status"
    - created 03/2025
    - Update 07/2026 

# Flink Project Management

When doing a project to deliver real-time processing there are a set of factors to consider. New project versus migration projects are not scoped the same, even if most of the time it is better for a migration project to start from the existing / updated business requirements, and leverage the lessons learned during the previous project to build a better solution.

At a high-level there are some mandatory components we need to consider when designing a data streaming processing solution:

<figure markdown="span">
![](./diagrams/hl_dsp_project.drawio.png)
</figure>

* Source of data: Apps, Databases, Transactional Systems, Devices
* Ingestion: get data into landing zone
* Processing: with data transformation and business rule implementation to prepare valuable analytical data product
* Serve: the data product to external consumers
* Consumers: Apps, Business Intelligence dashboard, Devices, MLops to prepare for machine learning model, and Agents/LLM

To support the scoping of those different sources and processing components, this chapter lists project activities and review questions by stage. Detailed event-level questions sit under Design; bounded vs unbounded data under [Shifting to real-time processing](#shifting-to-real-time-processing). 

## Target Architecture

As the data streaming processing will be done with Apache Flink and the Ingestion will be supported by Apache Kafka, we propose the following components in scope of supporting the solution. This is important to have this in mind to drive the interview sessions and the design tasks.

<figure markdown="span">
![](./diagrams/hl_sol_arch.drawio.png)
</figure>

## Scope Discovery

Even if we embrace building by iterations, and tune the scope over time, address these early; some stay recurrent across releases.

* What kind of solution is it (greenfield, migration, extension)?
* Who owns the data product and who consumes it (roles, not only systems)?
* Data loading patterns: snapshot, incremental, frequency of change; volume per source and frequency of new or updated records
* Data structure (structured vs unstructured); who owns schema definition and change approval
* Business logic to apply; state and time semantics of each pipeline (see Design**)
* Source semantics and data update pattern at origin

Use per-stage review questions for workshop-style coverage by diagram component. Use Data mesh alignment and generic streaming review when architecture spans domains or platforms.

## Per-stage review questions

Questions below map to the diagram: Sources, Ingestion, Processing, Serve, Consume. Each stage implies contracts: schema/registry, SLAs, and ownership of changes.

### Source of data

Apps, databases, transactional systems, devices.

* Who owns each source domain and who can approve schema or behavior changes?
* CDC vs application events vs files/APIs: which pattern per source, and why?
* Ordering guarantees at source (per key, per partition, none)? See Design → Event semantic.
* Idempotency and retry behavior of producers; risk of duplicates or gaps?
* Initial load vs ongoing change capture: full snapshot needed? Retention of source logs or binlog?
* Network and security path to ingestion (VPC, private link, credential rotation).

### Ingestion (landing zone)

* What is the landing contract: raw vs lightly normalized, format, partitioning, retention?
* Topic or stream naming, environment isolation, and access control model.
* Schema registration strategy: who registers, compatibility rules, subject or topic layout.
* Dead-letter or quarantine path for poison messages; replay from landing vs re-source.
* Ingestion SLAs (lag, completeness) and how they are measured. See Design → Scalability.

### Processing

Transformations, business rules, analytical data products.

* Clear definition of the data product: granularity, keys, refresh semantics, intended consumers. [See the Open Data Product Specification](https://opendataproducts.org/) to define metadata per data product.
* Stateful vs stateless operations; state TTL and cleanup; changelog vs upsert outputs.
* Joins across streams: watermark strategy, allowed lateness, handling late data. See Design/Event semantic.
* Versioning of business rules and safe rollout (feature flags, backfill strategy). See [shifting to real-time processing](#shifting-to-real-time-processing) for bounded recompute.
* Tests for pipelines: unit and integration, contract tests against schemas. See Design/Data Integrity.

### Serve

Expose the data product to consumers.

* Interface model: Kafka topic, API, warehouse sync, feature store, or other.
* Consumer onboarding: documentation, sample access, SLAs, breaking-change policy.
* Access patterns: batch pull vs streaming push and cost implications.
* Freshness and completeness SLOs advertised to consumers.

### Consumers

Apps, BI, devices, MLOps, agents/LLM.

* Latency and freshness requirements per consumer class.
* BI: materialized views vs direct stream subscribe; snapshot intervals.
* MLOps: training vs online features; point-in-time correctness if applicable.
* Agents and LLM: PII handling, grounding and source of truth, rate limits and cost controls. See Design → Privacy.

## Data mesh alignment

Use when multiple domains or teams own data and platforms.

* **Domain ownership**: Which bounded context owns each source and each derived data product? Who is the accountable product owner?
* **Data as a product**: Product sheet or equivalent: purpose, schema, SLAs, sample access, support channel.
* **Self-serve platform**: What the platform provides (ingestion patterns, Flink or SQL standards, catalog, observability) vs what domains build.
* **Federated computational governance**: Global policies (PII, retention, naming) vs local decisions; how exceptions are approved.
* **Discoverability**: Catalog and metadata, lineage from source to served product, ownership tags.
* **Mesh and streaming**: Stream and topic boundaries aligned with domain boundaries, or shared pipelines that blur ownership.

## Generic streaming review

Cross-cutting items that complement Design (per-stream detail).

* **Delivery semantics**: At-least-once vs exactly-once end-to-end; where idempotent sinks are required. Ties to Design → Event semantic.
* **Time semantics**: Processing time vs event time; clock skew; business definition of on-time delivery.
* **State and recovery**: Checkpoint interval, expected recovery time, savepoint strategy for upgrades.
* **Backfill and reprocessing**: Historical recompute without double-counting or inconsistent downstream state.
* **Schema evolution**: Forward and backward compatibility, consumer upgrade order, emergency rollback. Ties to Design→ Data Integrity.
* **Observability**: Lag, throughput, error rate; data quality checks in-stream vs offline.
* **Capacity and cost**: Peak vs steady state; autoscaling limits; growth of state, topics, and logs.
* **Multi-region and DR**: RPO and RTO for the streaming path; active-active vs failover.

## Shifting to Real-time Processing

*Some important elements: Flink can run batch or streaming. Connectors will not be the same, and most likely the business logic may differ too.*

* Assess if data is unbounded or bounded. Per-stage source of data and processing questions apply differently when data is bounded.
* For bounded data, how often is a new record added or an existing one modified?

In business analytics, there is a need to differentiate data tables according to their usage and reusability. There are two important concepts of this practice:

* The **Dimensions**, which provide the “who, what, where, when, why, and how” context surrounding a business process event. Dimension tables contain the descriptive attributes used by BI applications for ﬁltering and grouping the facts. 
* The **Facts**, which are the measurements that result from a business process event and are almost always numeric. The design of a fact table is entirely based on a physical activity, and not by the reports to produce from those facts. A fact table always contains foreign keys for each of its associated dimensions, as well as optional degenerate dimension keys and date/time stamps.

### The star schema

The star schema was defined in the late 1980s as a multidimensional data model to organize data in a data warehouse, preserve history, and reduce duplication. A star schema is used to denormalize business data into dimensions and facts it help to address analytical questions such as: "Which region had the highest revenue growth from millennial shoppers last quarter?". Doing such queries on transactional, OLAP, data schema will be... at minimum challenging.

The star schema gets its name because it looks like a star: a single, central Fact Table surrounded by multiple Dimension Tables (the points of the star)

The fact table connects to multiple other dimension tables along "dimensions" like date, driver, customer...

![](./diagrams/star_schema.drawio.png)

The **fact table** sits at the center. It records the what happened, as quantitative, measurable events (the "facts") of a business process.

* It contains mostly numbers (metrics) and foreign keys that link out to the dimensions.
* It is usually massive, growing by millions of rows daily, but very narrow (few columns).
* Example (Sales Fact Table): Quantity_Sold, Gross_Revenue, Discount_Amount, Tax_Paid.

**Dimension tables** (The "Context") surround the fact table. They provide the "who, what, where, when, and why" behind the numbers.

* It contains descriptive attributes, text, and categories.
* They are smaller, wider (lots of columns describing an entity), and change less frequently.
* Example (Product Dimension Table): Product_Name, SKU, Category, Brand, Color, Size.

When a user queries a star schema, they filter or group by the attributes in the Dimension tables (e.g., "Filter by Year 2026" and "Group by Brand") and aggregate the numbers in the Fact table (e.g., "Sum of Gross Revenue")

The star schema in figure above should help to answer questions like:
    * Which vehicle tier (dim_drivers) brings in the highest average tip amount (fact_trips)?
    * What is the most popular drop-off neighborhood (dim_locations) for Gold-tier customers (dim_customers) on weekends (dim_date)?
    
The following project illustrates how to implement the star schema using Flink:

* [Customer 360](https://jbcodeforce.github.io/flink_project_demos/c360/flink_project/#define-the-shift_left-utils-configuration)
* [Transaction analytics](https://github.com/jbcodeforce/flink_project_demos/tree/main/tx_processing)
* [A simple car rides data as a product with materialized table demonstration](https://github.com/jbcodeforce/code/flink-sql)

In Flink, a dimension may be created via a SQL statement and persisted as a table backed by a Kafka topic, JDBC, or files. When it is less reusable, a dimension can be a CTE within a larger Flink SQL statement.

???+ question "How does star schema help developing data as a product?"
    By its structure, a star schema is at the user interface for data as a product. It is denormalized (flattened), it requires minimal joins. It is highly intuitive: pick your context (dimension), pick your metric (fact) and run the query.

    They are optimized for read-heavy analytical queries, so cloud data warehouses can scan them at lightning speeds.
    
    A data product should solve a specific business problem for a specific domain. A star schema is naturally bounded around a single business process. The central fact table defines the exact scope of that product.

???+ info "How to support Type 2 slowly changing dimension (SCD) table?"
    Type 2 SCDs are designed to maintain a complete history of all changes to dimension data. When a change occurs, a new row is inserted into the table, representing the updated record, while the original record remains untouched. Each record in the table is typically assigned a unique identifier (often a surrogate key) to distinguish between different versions of the same dimension member. 

### Organizing the project repository

Medaillon architecture, star schema and data as a product lead to be prescriptive on the way to manage the project. From years of experience, we arrive to the following structure which helps support clear spearation of concerns and data engineers navigating code source. (Not all files are presented to this view). The sources, dimension, facts, views are represented in separate folders, so deployment CLI can deploy in layers. Data product are separated also in folder too, so the same CLI can deploy statements  per product.

```sh
pipelines
├── dimensions
│   ├── c360
│   │   └── dim_customer_transactions
│   │       ├── Makefile
│   │       ├── pipeline_definition.json
│   │       ├── sql-scripts
│   │       │   ├── ddl.dim_c360_customer_transactions.sql
│   │       │   └── dml.dim_c360_customer_transactions.sql
│   │       ├── tests
│   │       └── tracking.md
│   └── sdp
│       ├── dim_estimated_delivery
│       └── dim_order_fulfillment
├── facts
│   ├── c360
│   │   └── fct_customer_360_profile
│   │       ├── Makefile
│   │       ├── pipeline_definition.json
│   │       ├── sql-scripts
│   │       │   ├── ddl.c360_fct_customer_profile.sql
│   │       │   └── dml.c360_fct_customer_profile.sql
│   │       ├── tests
│   │       │   ├── ddl_dim_c360_customer_transactions.sql
│   │       │   ├── ddl_src_c360_app_usage.sql
│   │       │   ├── ddl_src_c360_customers.sql
│   │       │   ├── ddl_src_c360_loyalty_program.sql
│   │       │   ├── ddl_src_c360_support_ticket.sql
│   │       │   ├── insert_dim_c360_customer_transactions_1.sql
│   │       │   ├── insert_src_c360_app_usage_1.sql
│   │       │   ├── insert_src_c360_customers_1.sql
│   │       │   ├── insert_src_c360_loyalty_program_1.sql
│   │       │   ├── insert_src_c360_support_ticket_1.sql
│   │       │   ├── README.md
│   │       │   ├── test_definitions.yaml
│   │       │   └── validate_c360_fct_customer_profile_1.sql
│   │       └── tracking.md
│   └── sdp
│       └── fct_order_fulfillment
├── sources
│   ├── c360
│   │   ├── src_app_usage
│   │   ├── src_customers
│   │   ├── src_loyalty_program
│   │   ├── src_products
│   │   ├── src_support_ticket
│   │   ├── src_transactions
│   │   └── src_tx_items
│   └── sdp
│       ├── src_shipments
│       └── src_tracking_events
└── views
    ├── c360
    │   └── customer_analytics_c360
    └── sdp
        └── fulfillment_analytics
   
```

The following commands are used (see [shift_left utils](https://github.com/jbcodeforce/shift_left_utils)):

* **Create a project:** `shift_left project init a_project_name a_project_path --project-type kimball`
* **Adding table:** `shift_left table init fct_user $PIPELINES/facts --product-name c360`
* **Adding unit tests:**  `shift_left table init-unit-tests <table_name> --nb-test-cases 1 `
* **Deploying per layer:** `shift_left pipeline deploy --dir $PIPELINE/facts --compute-pool-id $CP_ID --may-start-descendants`
* **Deploying a product:** `shift_left pipeline deploy --product-name c360 --compute-pool-id $CP_ID`
* **Deploying a unique table:** `shift_left pipeline deploy --table-name fct_user --compute-pool-id $CP_ID --may-start-descendants`

This structure is compatible with `dbt` Confluent plugin (see [dbt chapter](../coding/dbt.md)). 

### FAQ on Flink Project Management

???+ question "Flink and Schema management"
    *  *Does CC Flink validate its output against a pre-registered schema?*  Yes and the `show create table ...` help to understand existing schema. When submitted a Flink statement  the last schema version is used.
    * *What is the schema subject naming convention for kafka topic created by Flink?*: the name of the table will be used. We recommend using naming convention to reflect the staging environment, may be the region, the data product and then the dim, fct, src... 
    * *Does CC Flink automatically register output schema of SQL transforms in Confluent SR?* yes when using `CREATE TABLE`.  
    * *How schema id is supported in Flink?* Confluent Cloud for Apache Flink now supports writing the Schema Registry schema ID to the Kafka record header. Set the new [key.format.id-encoding](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#flink-sql-create-table-with-key-format-id-encoding) and [value.format.id-encoding](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#flink-sql-create-table-with-value-format-id-encoding) table options to `header` to produce records without the Confluent wire-format payload prefix. This is useful when downstream consumers expect raw payloads or read schema IDs from the record header. Also, CC Flink can read records that weren't produced with a schema ID via [this process.](https://docs.confluent.io/cloud/current/flink/how-to-guides/read-records-without-schema-id-prefix.html)


## Design

Design is embedded in development. For each stream of records, assess the following (see also Per-stage review questions and Generic streaming review).

### Event semantic

* What are the business entity, and primary key?
* What the event time, and who initiate it?
* Will it be out-of-order events? (As part of a producer's retry)
* Do correlated events come with time gap and lateness?
* Is there any potential duplicate, also on retry or reload?
* Do the source of event in append, or already provide upsert semantic?
* Do we need to support exactly-once delivery?

### Scalability

* what is the data volume Bps and # of msg/s?
* What is the expected latency expected end-to-end?
* Do you expect bursty workload? How frequently? And why?
* How are you handling backpressure?
* What would be the risk if this system goes down by the minute/hour?

### Privacy

* How are you handling PII data end-to-end?
* Is PII detected/tagged pre-ingestion into the pipeline?
* Do you need to handle "Right To Be Forgotten" (GDPR/CCPA) requests?
* What would be the ideal tagging strategy?

### Data Integrity

* what is the current data governance practices? and tools?
* What does it look like when new data sources are added from an engineering standpoint?
* How relevant are the risks of schema changes creating disruption across the end-to-end solution? What are the consequences? How would you figure it out?
* Have you identified bad quality data downstream and identified root causes?

## Resources

* [Moving to a Data as a Product Architecture Chapter](https://jbcodeforce.github.io/flink-studies/methodology/data_as_a_product/)
* [Data topology methodology](https://jbcodeforce.github.io/data/data-topology/)
* [Data Mesh summary](https://jbcodeforce.github.io/data/#data-mesh)
* [EDA adoption assessment questions](https://jbcodeforce.github.io/eda-studies/methodology/ddd/eda_assessment/)
