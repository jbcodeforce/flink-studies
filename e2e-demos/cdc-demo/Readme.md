# Demonstration of CDC Debezium with Kafka and Flink

This demonstration addresses:

* [x] Running Postgresql on Kubernetes to define loan application and transaction tables in default schema. Populate 10 records in each table.
* [x] Use Confluent for kubernetes operator and a single node kafka cluster to run Confluent Platform for Flink
* [ ] Deploying CDC Debezium connector on Kafka Connect to watch the Postgresql tables
* [ ] Use `message.key.columns`  as non-primary key field for the Kafka message key.
* [ ] 

**Sources of information**:

* [Debezium 3.2 CDC](https://debezium.io/documentation/reference/3.2/)
* [Debezium connector for PostgreSQL](https://debezium.io/documentation/reference/3.3/connectors/postgresql.html#debezium-connector-for-postgresql)
* [Debezium PostgreSQL Source Connector for Confluent Platform](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html).
* [Debezium mySQL tutorial](https://debezium.io/documentation/reference/3.2/tutorial.html) with the [matching code in my db-play repo](https://github.com/jbcodeforce/db-play/tree/master/code/debezium-tutorial), [the notes](https://jbcodeforce.github.io/db-play/debezium/) and [github debezium examples](https://github.com/debezium/debezium-examples)


## Debezium PostgreSQL specifics

* The connector as a `logical decoding` capability to allow the extraction of the changes that were committed to the transaction log. This feature is in the output-plugin.
* Kafka connector uses the PG streaming replication protocol.
* Because of the regular purging of the Write-Ahead Log, the connector does not have the complete history of all changes that have been made to the database.
* When the connector is started, it builds a consistent snapshot of each of the database schemas, then it streams the changes per table.
* Changes are done dugin commit, and not post-commit. So inconsistency may happen.
* Need to create a replication user with specific privileges to access table, schemas...

## Pre-requisites:

* Colima or Orbstack installed and running: ensure you have the Kubernetes cluster set up. (`./start_colima.sh` under `deployment/k8s` or `make start_orbstack`)
* kubectl configured: your kubectl should be configured to interact with your k8s cluster.
  ```sh
  kubectl get ns
  ```

* Be sure to have [Confluent Platform running with Kafka brokers, Connector, Schema registry, Console, Flink operators...](../../deployment/k8s/cmf/README.md)

## Setup

The steps are:

1. [Install the Postgresql cloud native cnpg plugin for kubectl](https://cloudnative-pg.io/documentation/current/kubectl-plugin/)
1. Deploying a PostgreSQL Cluster using CloudNativePG, specifying multiple DB instances to support replication.
1. Connecting to the PostgreSQL admin console to work on the database
1. Install Debezium Connector

### Postgresql operator and cluster

There is a kubernetes operator for postgresql: [CloudNativePG](https://cloudnative-pg.io/) which needs to be installed. See [which version to install in this note](https://cloudnative-pg.io/documentation/current/installation_upgrade/) and modify the Makefile `deploy_postgresql_operator` target to reflect the selected version.

* Deploy the operator, in the cnpg-system namespacem with the needed roles, SA, and CRDs
  ```sh
  # in e2e-demos/cdc-demo/
  make deploy_postgresql_operator
  # The makefile target will do the following commands:
  kubectl apply --server-side -f \
    https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml
  ```

* Verify the installation, as it may take time for the first deployment: 

```sh
make verify_postgresql_operator
# same as
kubectl describe deployment -n cnpg-system cnpg-controller-manager
# or use
kubectl get deployment -n cnpg-system cnpg-controller-manager
```

The default configuration of the CloudNativePG operator comes with a Deployment of a single replica, which is suitable for most demonstrations.

* Create the PG Cluster and the PGadmin webapp
  ```sh
  make deploy_postgresql
  # this make target is the same as: 
  k apply -f infrastructure/pg-cluster.yaml
  # using cnpg plugin
  kubectl cnpg status pg-cluster -n pgdb
  ```

* Deploy pgadmin4 with yaml
  ```sh
  make deploy_pgadmin
  # this make target is the same as:
  kubectl apply -f infrastructure/pg-admin.yaml
  # or using cnpg plugin
  kubectl cnpg pgadmin4 --mode desktop pg-cluster
  # It automatically connects to the app database as the app user, making it ideal for quick demos
  ```

* Verify postgresql version by looking at the image element in:

```sh
k describe cluster pg-cluster -n pgdb  
kubectl get cluster pg-cluster-ro -n pgdb
```

* Verify the Postgresql database: `app` user's password

```sh
kubectl get secret app-secret -n pgdb -o=jsonpath='{.data.password}' | base64 -d
```

* Verify pg cluster services
CloudNativePG automatically creates three Kubernetes Services for your cluster:

  * pg-cluster-rw: Points to the primary instance (read-write).
  * pg-cluster-ro: Points to one of the replica instances (read-only, round-robin). This is the service you should use for your read-only applications.
  * pg-cluster-r: Points to any instance (primary or replica, round-robin) for general read operations.

```sh
kubectl get svc -l cnpg.io/cluster=pg-cluster -n pgdb
```

* Connect with psql:
```sh
k exec -ti -n pgdb pg-cluster-1 -c postgres  -- bash
# inside the pod
psql "host=pg-cluster-rw user=app dbname=app password=apppwd"
# in the psql shell create tables or sql queries
```

* The best option is to create tables, insert basic data with a k8s job. See config maps and job in the src/postgresql folder

```sh
k apply -f src/postgresql/create_cars_cm.yaml -n pgdb
k apply -f src/postgresql/create_car_table_job.yaml -n pgdb
```

* The PG admin web app is at [http://localhost:30001/](http://localhost:30001/) The user is admin@example.com / password123, and once logged, add a server with the user `app/apppwd` to connect `pg-cluster-rw` server the app database for read-write access. With the `pg-cluster-rw` server we can create tables inside PGadmin user interface.

* To create database we need jobs or remote exec to postgresql pod.

    ```sh
    k get pods -n pgdb
    k exec -ti pg-cluster-1 -n pgdb -- bash
    > psql -U postgres
    \c app
    \d
    create table .... 
    \dt
    ```

* Use python code to create loan_applications and transactions database and tables.

```sh
uv run python  src/create_loan_applications.py
uv run python  src/create_transactions.py
```

### Deploy Confluent Platform Connect

* [See last Kafka Connector descriptor and tags](https://docs.confluent.io/platform/current/connect/confluent-hub/index.html)
* [See Postgresql Source Connector](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html)
* [Debezium connector for Postgresql](https://debezium.io/documentation/reference/3.3/connectors/postgresql.html)

* Deploy Kafka Connect with Confluent Platform
  ```sh
  k apply -f infrastructure/kconnect.yaml -n confluent
  ```

* Validate the Kafka connect services are visible
  ```sh
  k get  svc -n confluent
  ```

* Verify the topics and Kafka cluster
  ```sh
  kubectl get pods -n confluent  -w 
  ```
  
* Access to the console: [http://controlcenter-ng.confluent.svc.cluster.local:9021/home](http://controlcenter-ng.confluent.svc.cluster.local:9021/home)

### Deploy Postgresql CDC Debezium connector


#### 1. Enable Logical Replication on PostgreSQL

Debezium requires PostgreSQL logical replication. Update the pg-cluster.yaml to include:


To deploy a Debezium connector, you need to deploy a Kafka Connect cluster with the required connector plug-in(s), before instantiating the actual connector itself.

* Perform a port forward to access to the Connect REST API

```sh
k port-forward connect-0 8083:8083 -n confluent
```

* Test list of connectors

```sh
curl -H "Accept:application/json" localhost:8083/connectors/
```


* Deploy the connector
```
curl -X POST -H "Content-Type: application/json" \
  --data @infrastructure/cdc_debezium.json \
  http://localhost:8083/connectors#### 5. Verify Connector Status
```

* Check connector status
```
curl localhost:8083/connectors/tx-loan-connector/status
```

* List created topics
```
kubectl exec -it kafka-0 -n confluent -- kafka-topics --list --bootstrap-server localhost:9092 | grep cdc#### 6. Test CDC Events
```

* Insert test data and verify events appear in Kafka topics

```
kubectl exec -it kafka-0 -n confluent -- kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic cdc.public.loan_applications \
  --from-beginning

```

* [Debezium Product documentation](https://debezium.io/documentation/reference/stable/connectors/postgresql.html#debezium-connector-for-postgresql). 
* [Confluent Cloud Kafka Connector Postgresql CDC v2 Debezium](https://docs.confluent.io/cloud/current/connectors/cc-postgresql-cdc-source-v2-debezium/cc-postgresql-cdc-source-v2-debezium.html).
* [Confluent Platform connector](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html)

To summarize here are the important steps to proceed:



```
```