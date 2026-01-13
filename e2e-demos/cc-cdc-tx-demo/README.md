# A Confluent Cloud Demo for Transaction Processing

## Goals

The demonstration presents a hands-on guidance for the following:

* [x] Integrate with RDS and CDC Debezium v2 Connector on Confluent Cloud 
* [ ] Decoding Debezium message envelope using Flink or using the json-debezium-registry setting in CC Flink 
* [ ] Understanding how to replace existing ETL processes with Flink
* [ ] Sliding window aggregations over transactions grouped by cardholder (1 minute to 1 day windows)
* [ ] How to propagate delete operations to sink bucket
* [ ] Maintain data order for transactional systems (CRITICAL)
* [ ] How TableFlow + Flink ensure ordered delivery
* [ ] What monitoring and observability requirements exist?
* [ ] How to handle microservices that produce/consume Kafka data without going through Debezium? (Outbox pattern)

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
│   └── DEPLOYMENT.md            # Step-by-step deployment guide
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

For incremental deployment (e.g., RDS first, then Confluent Cloud), see the detailed [Deployment Guide](./IaC/DEPLOYMENT.md).


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

1. As a preparation deploy all the infrastructure using Terraform in one shot or [step-by-step](./IaC/DEPLOYMENT.md).

## Test Data Generation

A Python CLI tool is provided to generate test customers and transactions for testing the CDC pipeline.

### Quick Start

* Getting RDS Endpoint

```bash
cd IaC
terraform output rds_address
```

```bash
# Install dependencies (using uv)
cd data-generators
uv sync

# Generate 10 customers and 10 transactions (one-shot)
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password>

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


## To Do

* [x] Add sample data generator script
* [x] Create ML inference container Dockerfile
* [ ] Add monitoring dashboards (Grafana/Datadog)
* [ ] Document VPC peering setup for non-public RDS
* [ ] Add end-to-end integration tests
* [ ] Create Redshift external schema SQL scripts

## Sources of knowledge

* [This book for changelog mode explanations]()
* [confluent networking overview](https://docs.confluent.io/cloud/current/networking/overview.html#cloud-networking)
* [Connect to RDS using psql](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.psql.html)
* [Troubleshooting connections to your RDS for PostgreSQL instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.Troubleshooting.html)
