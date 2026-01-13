# A Confluent Cloud Demo for Transaction Processing using CDC

## Goals

The demonstration presents a hands-on guidance for the following requirements:

* [x] Integrate with AWS RDS Postgres and CDC Debezium v2 Kafka Connector deployed as managed service on Confluent Cloud (CC)
* [x] Decoding Debezium message envelope using Flink or using the json-debezium-registry setting in CC Flink 
* [ ] Understanding how to replace existing ETL processes with Flink
* [ ] Sliding window aggregations over transactions grouped by cardholder (1 minute to 1 day windows)
* [ ] How to propagate delete operations to sink bucket [See section](./cc-flink-sql/README.md#propagating-the-operation-delete-too)
* [ ] Maintain data order for transactional systems
* [ ] How TableFlow + Flink ensure ordered delivery
* [ ] Integrate with a [ML scoring service](./tx_scoring/README.md)
* [ ] What monitoring and observability requirements exist?
* [x] How to handle microservices that produce/consume Kafka data without going through Debezium? ([Outbox pattern](#outbox-pattern))

### To Do

* [x] Terraform to get VPC, subnets, configure service accounts, role binding,  deploy RDS, create tables, specify inbound rules for security group, Debezium connector, 
* [ ] Terraform for Redshift and S3 buckets, S3 Sink connector.
* [x] Add sample data generator code to support the demonstration
* [x] Create ML inference code with  Docker container and ECS deployment
* [ ] Add monitoring dashboards (Grafana)
* [ ] Add end-to-end integration tests
* [ ] Create Redshift external schema SQL scripts


## Architecture

![](./images/proposed_arch.drawio.png)

### Component List

| Component | Description | Resource Naming |
|-----------|-------------|-----------------|
| RDS PostgreSQL | Database with customers and transactions tables | `card-tx-db-{id}` |
| VPC | Existing VPC (passed via terraform variable) | N/A |
| CDC Debezium v2 | Source connector capturing changes from PostgreSQL | `card-tx-cdc-source` |
| Flink Compute Pool | Processing Debezium messages, enrichment, aggregations | `card-tx-compute-pool-{id}` |
| ML Inference | ECS/Fargate container for fraud scoring | `card-tx-ml-inference-service` |
| S3 Sink Connector | Writes enriched data to S3 in Parquet format | `card-tx-s3-sink` |
| TableFlow | Automatic Iceberg table management | Enabled on enriched topics |
| Redshift Serverless | Query layer for S3 Iceberg tables (optional) | `card-tx-workgroup-{id}` |


### Topics

| Topic | Owner | Description |
| ----- | ----- | ----------- |
| `card-tx.public.customers` | CDC Debezium | customer records consumed from Postgresql DB |
| `card-tx.public.transactions` |CDC Debezium | transaction records consumed from Postgresql DB |
| `dim_customers` | Flink | Customer dimension - from debezium envelop - no duplicate |
| `dim_transactions` | Flink | |


### Project Structure

```
cc-cdc-tx-demo/
├── AGENTS.md                    # This file
├── images/
│   └── proposed_arch.drawio.png # Architecture diagram
├── IaC/                         # Terraform Infrastructure
│   ├── providers.tf             # AWS, Confluent providers
│   ├── variables.tf             # Input variables (card-tx prefix)
│   ├── outputs.tf               # Connection strings, endpoints
│   ├── aws.tf                   # VPC data source, RDS, Security Groups, S3
│   ├── confluent.tf             # Environment, Cluster, SR, Flink Pool, Topics
│   ├── service-accounts.tf      # Service accounts, API keys, ACLs
│   ├── connectors.tf            # CDC Debezium v2, S3 Sink connectors
│   ├── ml-inference.tf          # ECS cluster, ECR, task definition, service
│   ├── redshift.tf              # Optional Redshift Serverless
│   ├── terraform.tfvars.example # Example variables file
│   └── README.md            # Step-by-step deployment guide
├── data-generators/             # Test Data Generation
│   ├── generate_test_data.py   # CLI tool to generate customers/transactions
│   ├── pyproject.toml          # Python project config (uv)
│   └── README.md                # Usage instructions
└── cc-flink-sql/                # Flink SQL Statements
    ├── 01-customers-table.sql   # Customers table definition
    ├── 02-transactions-table.sql # Transactions table definition
    ├── 03-sliding-aggregations.sql # Sliding window aggregations
    ├── 04-ml-enrichment.sql     # ML inference integration
    ├── 05-enriched-transactions.sql # Customer + transaction joins
    └── 06-delete-propagation.sql # Delete handling patterns
```


### Domain Data Model

The transaction processing domain consists of two core source tables:

#### Entities

##### customers
Customer master data with deduplication support (upsert mode).

| Column | Type | Description |
|--------|------|-------------|
| `account_number` | VARCHAR | Primary key - unique customer identifier |
| `customer_name` | VARCHAR | Full name of the customer |
| `email` | VARCHAR | Customer email address |
| `phone_number` | VARCHAR | Contact phone number |
| `date_of_birth` | TIMESTAMP(3) | Customer birth date |
| `city` | VARCHAR | Customer city location |
| `created_at` | TIMESTAMP_LTZ(3) | Record creation timestamp (watermark) |

##### transactions
Financial transaction records with deduplication support (upsert mode).

| Column | Type | Description |
|--------|------|-------------|
| `txn_id` | VARCHAR(36) | Primary key - unique transaction identifier |
| `account_number` | VARCHAR(255) | Foreign key to customer |
| `timestamp` | TIMESTAMP_LTZ(3) | Transaction timestamp (watermark) |
| `amount` | DECIMAL(10,2) | Transaction amount |
| `currency` | VARCHAR(5) | Currency code (e.g., USD) |
| `merchant` | VARCHAR(255) | Merchant name |
| `location` | VARCHAR(255) | Transaction location |
| `status` | VARCHAR(255) | Transaction status |
| `transaction_type` | VARCHAR(50) | Type of transaction |

### Outbox pattern

[The outbox pattern](https://jbcodeforce.github.io/eda-studies/patterns/#transactional-outbox) is a classical design pattern for event-driven microservice. The approach is to have a dedicated table to persist business events designed for asynchronous consumers. As the consumers may not be known upfront the approach is to use pub/sub with long persistence, so Kafka as a technology of choice. Existing code sample presents this pattern [in this repository](https://github.com/jbcodeforce/vaccine-order-mgr?tab=readme-ov-file) using Java Quarkus and Debezium outbox extension.

Any microservice that wants to implement the outbox pattern needs to design the business events to represent the change of state of the business entity the service manages. It is recommended to adopt [event-storming](https://jbcodeforce.github.io/eda-studies/methodology/event-storming/)  and [domain-driven design](https://jbcodeforce.github.io/eda-studies/methodology/ddd/) to model the business events and microservice together. 

[Future implementation](./oubox-customer-service/README.md) will demonstrate the method for the customer microservice.

## Infrastructure as Code

The [IaC](./IaC/) folder includes the Terraform to deploy the solution on AWS and Confluent Cloud.

### Deployment Flow

**Option 1: Deploy Everything at Once**

1. Configure terraform.tfvars
2. terraform init
3. terraform plan
4. terraform apply]
5. Wait for RDS + CDC
6. Insert sample data using [Data Generator](./data-generators/README.md)
7. Run Flink SQL statements [Flink SQL](./cc-flink-sql/README.md)
8. Verify enriched topics
9. Query S3/Redshift

**Option 2: Step-by-Step Deployment**

For incremental deployment (e.g., RDS first, then Confluent Cloud), see the detailed [Deployment Guide](./IaC/README.md).


### Key Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `prefix` | Resource naming prefix | `card-tx` |
| `existing_vpc_id` | Your existing VPC ID | (required) |
| `cloud_region` | AWS region | `us-east-2` |
| `confluent_cloud_api_key` | Confluent Cloud API key | (required) |
| `confluent_cloud_api_secret` | Confluent Cloud API secret | (required) |
| `enable_tableflow` | Enable TableFlow for Iceberg | `true` |
| `enable_redshift` | Deploy Redshift Serverless | `false` |
| `confluent_cloud_cidr_blocks` | IP Addresses for CC to access RDS | (required) |

## Flink Processing

[See dedicated note](./cc-flink-sql/README.md) for the processing of Debezium envelop, addressing deduplication, sliding window aggregation...

## Demonstration Script

1. As a preparation to the demonstration deploy all the infrastructure using Terraform in one shot:
    ```sh
    terraform init
    terraform plan
    terraform apply
    ```

    or [step-by-step with detail instructions](./IaC/README.md). This is recommended the first time to understand what is done.

1. Once RDS in place and Source Connector running, use the data generator to create 10 base customers and transactions. ([See Data Generator readme for more details](./data-generators/README.md))
    * Getting RDS Endpoint and send 10 records in each table:
        ```bash
        cd IaC
        terraform output rds_address
        # Install dependencies (using uv)
        cd ../data-generators
        uv sync
        # Generate 10 customers and 10 transactions (one-shot)
        uv run generate_test_data.py \
        --db-host <rds-endpoint> \
        --db-name cardtxdb \
        --db-user postgres \
        --db-password <password>
        ```

1. [Execute the steps in the Flink table analysis](./cc-flink-sql/README.md#table-analysis) to explain the envelop processing. 


1. Aggregation deployment and 
    ```sh
    # Generate transactions continuously (for live demo)
    uv run generate_test_data.py \
    --db-host <rds-endpoint> \
    --db-name cardtxdb \
    --db-user postgres \
    --db-password <password> \
    --run-forever \
    --interval 5
    ```

See [data-generators/README.md](./data-generators/README.md) for detailed usage and options.


## Sources of knowledge

* [This book for changelog mode explanations](https://jbcodeforce.github.io/flink-studies/concepts/flink-sql/#changelog-mode)
* [confluent networking overview](https://docs.confluent.io/cloud/current/networking/overview.html#cloud-networking)
* [Connect to RDS using psql](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.psql.html)
* [Troubleshooting connections to your RDS for PostgreSQL instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.Troubleshooting.html)
* [Event-driven architecture and design patterns - JBoyer's book](https://jbcodeforce.github.io/eda-studies/)
