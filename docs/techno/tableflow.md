# Confluent TableFlow

this is to track eneblement and knowledge. [The matching chapter is](./cc-tableflow.md)

## Tableflow fundamentals

Why operational Kafka data needs table materialization
Iceberg and Delta Lake fundamentals
Schema Registry dependencies
Append versus CDC/upsert semantics
Snapshot, metadata, manifest, and data-file concepts
Table maintenance, compaction, retention, and cleanup
Hands-on goal: enable Tableflow on a schema-backed topic and query it from an analytics engine.

Week 2: Storage and security
Master:

Confluent-managed storage versus BYOS
S3 and ADLS storage patterns
Provider integrations and IAM roles
KMS/BYOK permissions
Region requirements
Private networking constraints
Critical rule: external catalog synchronization requires custom storage; Confluent-managed Tableflow storage does not sync to external catalogs.  

Also learn the private-networking tradeoffs: the Iceberg REST Catalog and Unity/Snowflake external integrations have networking limitations, while AWS Glue has a supported private-network pattern in relevant AWS deployments.  

Week 3: Iceberg REST Catalog
Be able to explain and demonstrate:

REST Catalog API concepts
Catalog endpoint, namespace, credentials, and warehouse/storage access
Spark, Athena, Trino, and Snowflake connectivity
Credential vending differences between managed storage and BYOS
Read-only consumption of Tableflow-managed tables
The managed-storage quick start provides a practical Spark/Athena path.  

Week 4: External catalog integrations
Build one lab for each:

Catalog	Format	Primary skill
AWS Glue	Iceberg	IAM, Lake Formation, S3, read-only governance
Snowflake Open Catalog / Polaris	Iceberg	REST authentication, warehouse and scope configuration
Databricks Unity Catalog	Delta Lake	Service principals, external locations, catalog permissions



External integrations are cluster-level, and all compatible materialized topics can be published through the integration. Generally, only one integration per catalog type is allowed on a cluster.  

Use these labs:

AWS Glue integration
Snowflake Open Catalog / Polaris integration
Unity Catalog integration
Week 5: Catalog operations and governance
Master:

Namespace and database/schema naming
Catalog integration lifecycle
Per-topic sync status
Materialization status versus catalog publication status
RBAC and least privilege
Catalog migration and cleanup
Consumer access patterns
Table ownership and read-only boundaries
A materialization pipeline can be healthy while catalog publication fails independently. Catalog failures do not necessarily stop Tableflow from writing table files.  

Learn the RBAC model: Tableflow access generally follows Kafka and Confluent Cloud resource permissions; cluster administrators manage integrations, while topic owners have narrower topic-level capabilities.  

Week 6: Expert-level customer design
Practice designing solutions for:

AWS + Glue + Athena/Spark
Snowflake-centric lakehouse architectures
Databricks + Unity Catalog + Delta Lake
Multi-catalog publication from one Kafka cluster
Private networking
BYOK/KMS-encrypted storage
CDC and upsert workloads
Schema evolution
Cross-cloud architectures
Catalog migration and namespace standardization
3. Memorize these operational rules
Enable Tableflow on a topic before enabling external catalog synchronization.  
External catalog sync requires materialized topics.
Treat Tableflow-managed tables as read-only in external catalogs.  
Do not manually delete or modify Tableflow-managed files.
Do not enable external Glue optimizers such as compaction, snapshot retention, or orphan-file deletion; Tableflow manages those functions.  
Validate storage access, catalog permissions, KMS access, and network reachability separately.
Diagnose materialization status and catalog sync status independently.
Use meaningful external namespaces rather than opaque cluster IDs where supported.  
4. Become fluent with the CLI and APIs
Know how to perform these operations:

confluent tableflow catalog-integration list
confluent tableflow catalog-integration describe <id>
confluent tableflow catalog-integration create <name> --type <aws|snowflake|unity>
confluent tableflow catalog-integration update <id>
confluent tableflow catalog-integration delete <id>
bash

The CLI supports create, list, describe, update, and delete workflows for catalog integrations.  

Also study the Catalog Integrations API reference.  

5. Use an expert troubleshooting framework
When a catalog integration fails, inspect in this order:

Topic: Is it schema-backed and Tableflow-enabled?
Materialization: Is Tableflow writing files successfully?
Storage: Can Tableflow write, and can the catalog read the location?
Credentials: Are IAM roles, service principals, OAuth credentials, and scopes correct?
Permissions: Are catalog, schema, external-location, object, and KMS permissions present?
Network: Can Tableflow reach the external catalog?
Format: Does the topic’s Iceberg/Delta format match the catalog?
Namespace: Is the database, schema, or namespace valid?
Consumer: Can the analytics engine access both metadata and data files?
This separation is essential because catalog publication can fail even when table materialization succeeds.  

6. Your expert benchmark
You are ready to position yourself as an expert when you can:

Draw the end-to-end architecture from memory.
Explain Iceberg REST Catalog versus Glue, Polaris, and Unity Catalog.
Configure one complete lab without following a guide.
Explain BYOS, KMS, IAM, RBAC, and private-network implications.
Troubleshoot a failed sync using status and permissions evidence.
Recommend Iceberg versus Delta Lake based on customer requirements.
Explain why external consumers should not mutate Tableflow tables.
Use Console, CLI, and API approaches interchangeably.
Design a multi-catalog architecture with clear ownership and governance.
Deliver a customer workshop that includes architecture, demo, security, and failure recovery.
