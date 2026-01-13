# CDC Debezium Demo with Kafka and Flink

This demonstration shows how to capture database changes from PostgreSQL using Debezium CDC, stream them to Kafka, and consume them with Flink SQL.

## What This Demo Covers

- [x] Running PostgreSQL on Kubernetes with CloudNativePG operator
- [x] Defining loan_applications and transactions tables with sample data
- [x] Deploying Confluent Platform with Kafka Connect
- [x] Deploying Debezium CDC connector to watch PostgreSQL tables
- [x] Consuming CDC events with Flink SQL
- [x] Using `message.key.columns` for custom Kafka message keys

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌───────────┐ │
│  │  PostgreSQL │────▶│   Debezium   │────▶│    Kafka    │────▶│ Flink SQL │ │
│  │   (pgdb)    │ WAL │  Connector   │     │ (confluent) │     │           │ │
│  └──────┬──────┘     └──────────────┘     └──────┬──────┘     └───────────┘ │
│         │                   │                     │                          │
│         │            Replication Slot      CDC Topics:                       │
│         │            Publication           • cdc.public.transactions         │
│         │                                  • cdc.public.loan_applications    │
│         │                                  • schema-changes.cdc              │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │   PGAdmin    │                                                            │
│  │  (Web UI)    │                                                            │
│  └──────────────┘                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### How PostgreSQL CDC Works

Debezium uses PostgreSQL's **logical replication** feature to capture changes:

1. **Write-Ahead Log (WAL)**: PostgreSQL records all changes to the WAL before writing to tables. The `wal_level=logical` setting enables extracting change data from the WAL.

2. **Replication Slot**: Debezium creates a replication slot (`debezium_slot`) that tracks which WAL position has been consumed. This prevents PostgreSQL from purging WAL segments that haven't been read.

3. **Publication**: The `pgoutput` plugin uses PostgreSQL publications to define which tables to capture. Debezium creates a publication (`dbz_publication`) for the monitored tables.

4. **Streaming Protocol**: The connector uses PostgreSQL's streaming replication protocol to receive changes in real-time after the initial snapshot.

### Required Permissions

The database user needs specific privileges for CDC to work:

| Permission | Purpose |
|------------|---------|
| `REPLICATION` | Required to create replication slots and stream WAL data |
| `SELECT` on tables | Required to perform initial snapshot |
| `CREATE` on schema | Required to create the publication (if using `publication.autocreate.mode=filtered`) |

The demo grants these with:
```sql
ALTER USER app REPLICATION;
```

### Pre-created Kafka Topics

Confluent Platform may have topic auto-creation disabled. The demo pre-creates these topics:

| Topic | Purpose |
|-------|---------|
| `cdc.public.transactions` | CDC events for transactions table |
| `cdc.public.loan_applications` | CDC events for loan_applications table |
| `schema-changes.cdc` | Internal topic for Debezium schema history |

### Key Debezium Behaviors

- **Initial Snapshot**: When started, Debezium performs a consistent snapshot of all table data before streaming changes.
- **Eventual Consistency**: Changes are captured at commit time. In-flight transactions are not visible until committed.
- **WAL Retention**: The replication slot prevents WAL from being purged, which can cause disk space issues if the connector is stopped for extended periods.

## Quick Start

### Prerequisites

1. **OrbStack** installed with Kubernetes enabled
2. **kubectl** configured to use OrbStack's Kubernetes
3. **Confluent Platform** deployed (see `deployment/k8s/cfk/`)
4. **Confluent CLI** for Flink shell access
5. **uv** Python package manager (for data loading scripts)

### One-Command Setup

```sh
# From e2e-demos/cdc-demo/
make demo_setup
```

This command will:
1. Start OrbStack Kubernetes
2. Deploy CloudNativePG operator
3. Deploy PostgreSQL cluster with logical replication enabled
4. Deploy PGAdmin web UI

### Deploy Kafka Connect

After Confluent Platform is running:

```sh
make deploy_connect
```

### Run the Demo

```sh
make demo_run
```

This loads sample data and deploys the Debezium connector.

### Cleanup

```sh
make demo_cleanup
```

## Step-by-Step Guide

To really understand what is going-on...

### 1. Start Kubernetes (OrbStack)

```sh
make start_orbstack
```

Verify the cluster is running:

```sh
kubectl get ns
```

### 2. Deploy PostgreSQL

Deploy the CloudNativePG operator and PostgreSQL cluster:

```sh
make deploy_postgresql_operator
make wait_postgresql_operator
make deploy_postgresql
make deploy_pgadmin
```

Verify PostgreSQL is running:

```sh
make verify_postgresql
```

Access PGAdmin at [http://localhost:30001](http://localhost:30001):
- Email: `admin@example.com`
- Password: `password123`

Connect to the database using:
- Host: `pg-cluster-rw`
- Port: `5432`
- Database: `app`
- User: `app`
- Password: `apppwd`

### 3. Deploy Confluent Platform

Follow the instructions in `deployment/k8s/cfk/`:

```sh
cd ../../deployment/k8s/cfk
make deploy
cd -
```

### 4. Deploy Kafka Connect with Debezium

```sh
make deploy_connect
```

Wait for Connect to be ready:

```sh
kubectl get pods -n confluent -w
```

### 5. Load Sample Data

```sh
make port_forward_pg
# Wait a few seconds for port-forward
uv run python src/create_loan_applications.py --small
uv run python src/create_transactions.py --small
```

Verify the data:

```sh
make verify_tables
```

### 6. Deploy Debezium Connector

```sh
make port_forward_connect
# Wait a few seconds
make deploy_connector
```

Verify the connector is running:

```sh
make verify_connector
```

There is a s single tx-loan-connector as it captures changes from both tables:
* public.transactions → cdc.public.transactions topic
* public.loan_applications → cdc.public.loan_applications topic

as we can see by running:
```sh
curl -s localhost:8083/connectors/tx-loan-connector | jq '.config["table.include.list"]'
# returns
# public.transactions,public.loan_applications
```

This is the standard Debezium pattern - one connector per database (or logical grouping), capturing multiple tables. Each table's changes go to a separate topic named {topic.prefix}.{schema}.{table}.

### 7. Verify CDC Topics

```sh
make list_cdc_topics
```

You should see:
- `cdc.public.loan_applications`
- `cdc.public.transactions`

Consume some messages:

```sh
make consume_loan_applications
make consume_transactions
```

### 8. Query with Flink SQL

There are two options for running Flink SQL queries:

#### Option A: Apache Flink OSS

Deploy the open-source Apache Flink session cluster:

```sh
# Deploy Flink cluster with Kafka connectors
make deploy_flink

# Wait for pods to be ready
make verify_flink

# Open Flink Web UI (optional)
make port_forward_flink_ui
# Access at http://localhost:8081

# Open Flink SQL client
make flink_sql_client
```

In the SQL client, create the CDC tables:

```sql
-- Create loan_applications table
CREATE TABLE loan_applications (
    application_id STRING,
    customer_id STRING,
    loan_type STRING,
    loan_amount_requested DOUBLE,
    loan_status STRING,
    fraud_flag BOOLEAN,
    PRIMARY KEY (application_id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'cdc.public.loan_applications',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'properties.group.id' = 'flink-cdc-loan-consumer',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json'
);

-- Query the data
SELECT application_id, customer_id, loan_type, loan_amount_requested, loan_status 
FROM loan_applications;
```

#### Option B: Confluent Manager for Flink (CMF)

Requires a valid Confluent Platform license.

```sh
# Port-forward CMF
make port_forward_cmf

# Open Flink shell via Confluent CLI
confluent flink shell --environment dev-env --url http://localhost:8084
```

#### Full DDL Files

The complete table definitions are in `src/flink-sql/`:
- `ddl.loan_applications.sql` - Loan applications CDC table
- `ddl.transactions.sql` - Transactions CDC table
- `query.sample.sql` - Sample queries

View them with:
```sh
make show_flink_ddl
```

## Make Targets Reference

| Target | Description |
|--------|-------------|
| `make help` | Show all available targets |
| `make demo_setup` | Complete demo setup |
| `make demo_run` | Load data and deploy connector |
| `make demo_cleanup` | Clean up all resources |
| `make start_orbstack` | Start OrbStack Kubernetes |
| `make deploy_postgresql` | Deploy PostgreSQL cluster |
| `make deploy_connect` | Deploy Kafka Connect |
| `make deploy_connector` | Deploy Debezium connector |
| `make verify_connector` | Check connector status |
| `make list_cdc_topics` | List CDC topics in Kafka |
| `make show_flink_ddl` | Display Flink SQL DDLs |
| `make deploy_flink` | Deploy Apache Flink OSS cluster |
| `make flink_sql_client` | Open Flink SQL client |
| `make port_forward_flink_ui` | Access Flink Web UI |
| `make undeploy_flink` | Remove Flink cluster |

## File Structure

```
cdc-demo/
├── Makefile                 # Demo automation
├── Readme.md                # This file
├── pyproject.toml           # Python dependencies
├── infrastructure/
│   ├── pg-cluster.yaml      # PostgreSQL cluster config
│   ├── pg-admin.yaml        # PGAdmin deployment
│   ├── kconnect.yaml        # Kafka Connect with Debezium
│   ├── cdc_debezium.json    # Debezium connector config
│   ├── debezium.yaml        # Secrets and RBAC
│   └── flink/               # Apache Flink OSS deployment
│       ├── namespace.yaml
│       ├── flink-config.yaml
│       ├── jobmanager.yaml
│       └── taskmanager.yaml
├── datasets/
│   ├── loan_applications_small.csv   # 15 sample records
│   ├── transactions_small.csv        # 15 sample records
│   ├── loan_applications.csv         # Full dataset (50K)
│   └── transactions.csv              # Full dataset (50K)
└── src/
    ├── create_loan_applications.py   # Data loading script
    ├── create_transactions.py        # Data loading script
    ├── config.py                     # DB config helper
    ├── local_db.ini                  # DB connection settings
    └── flink-sql/
        ├── ddl.loan_applications.sql # Flink table DDL
        ├── ddl.transactions.sql      # Flink table DDL
        └── query.sample.sql          # Sample queries
```

## Debezium Configuration

The connector configuration in `infrastructure/cdc_debezium.json` includes:

- **plugin.name**: `pgoutput` - PostgreSQL native logical decoding
- **slot.name**: `debezium_slot` - Replication slot name
- **publication.name**: `dbz_publication` - Publication for filtered tables
- **topic.prefix**: `cdc` - Prefix for Kafka topics
- **table.include.list**: `public.transactions,public.loan_applications`

## PostgreSQL Configuration

The CloudNativePG cluster is configured with logical replication enabled:

```yaml
postgresql:
  parameters:
    wal_level: logical
    max_replication_slots: 4
    max_wal_senders: 4
```

## Troubleshooting

### Connector fails to start

Check connector status and logs:

```sh
make verify_connector
kubectl logs connect-0 -n confluent
```

### No CDC events in Kafka

1. Verify tables exist in PostgreSQL:
   ```sh
   make verify_tables
   ```

2. Check replication slot:
   ```sh
   kubectl exec -it pg-cluster-1 -n pgdb -- psql -U app -d app -c "SELECT * FROM pg_replication_slots;"
   ```

3. Verify publication:
   ```sh
   kubectl exec -it pg-cluster-1 -n pgdb -- psql -U app -d app -c "SELECT * FROM pg_publication_tables;"
   ```

### Connect pod not starting

Ensure Confluent Platform is fully deployed:

```sh
kubectl get pods -n confluent
```

The Connect pod may take several minutes to download and install the Debezium plugin.

## References

- [Debezium Documentation](https://debezium.io/documentation/reference/3.2/)
- [Debezium PostgreSQL Connector](https://debezium.io/documentation/reference/3.3/connectors/postgresql.html)
- [Confluent Platform Debezium Connector](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/current/)
- [Flink SQL Debezium Format](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/formats/debezium/)
* [Debezium mySQL tutorial](https://debezium.io/documentation/reference/3.2/tutorial.html) with the [matching code in my db-play repo](https://github.com/jbcodeforce/db-play/tree/master/code/debezium-tutorial), [the notes](https://jbcodeforce.github.io/db-play/debezium/) and [github debezium examples](https://github.com/debezium/debezium-examples)