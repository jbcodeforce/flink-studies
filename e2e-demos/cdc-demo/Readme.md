# Demonstration of CDC Debezium with Flink

The demonstration addresses:

* Running Postgresql on Kubernetes to define loan application and transaction tables.
* Use Confluent for kubernetes operator and a single node cluster to run Confluent Platform for Flink
* Deploying CDC Debezium connector on Kafka Connect to watch the Postgresql table
* Use `message.key.columns` to use a non-primary key field for the Kafka message key.

See [Debezium PostgreSQL Source Connector for Confluent Platform](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html).

## Pre-requisites:

* Colima installed and running: ensure you have a Colima Kubernetes cluster set up. (`./start_colima.sh` under `deployment/k8s`)
* kubectl configured: your kubectl should be configured to interact with your Colima cluster.
  ```sh
  kubectl get ns
  ```
* [Install the postgreql cloud native snpg plugin for kubectl](https://cloudnative-pg.io/documentation/current/kubectl-plugin/)

## Setup

The steps are:

1. Installing the CloudNativePG Operator on your Kubernetes cluster.
1. Deploying a PostgreSQL Cluster using CloudNativePG, specifying multiple instances for replication.
1. Connecting to the admin console to work on the database 

### Postgresql

There is a kubernetes operator for postgresql: [CloudNativePG](https://cloudnative-pg.io/) which needs to be installed. See [which version to install in this note](https://cloudnative-pg.io/documentation/1.25/installation_upgrade/) and modify the Makefile `deploy_postgresql_operator` target to reflect the selected version.

* Deploy the operator:
```sh
# in e2e-demos/cdc-demo/
make deploy_postgresql_operator
# The makefile target will do:
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
# this make target is  same as 
k apply -f infrastructure/pg-cluster.yaml
# using cnpg plugin
kubectl cnpg status pg-cluster -n pgdb
# Deploy pgadmin4 with yaml
make deploy_pgadmin
# this make target is the same as
kubectl apply -f infrastructure/pg-admin.yaml
# or using cnpg plugin
kubectl cnpg pgadmin4 --mode desktop pg-cluster
# It automatically connects to the app database as the app user, making it ideal for quick demos
```

* Verify postgresql version by looking at the image element in:

```sh
k describe cluster pg-cluster -n pgdb  
kubectl get cluster my-read-only-cluster -n pgdb
```

* Verify the app user password

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

* Connect with psql
```sh
k exec -ti -n pgdb pg-cluster-1 -c postgres  -- bash
# inside the pod
psql "host=pg-cluster-rw user=app dbname=app password=apppwd"
# in the psql shell create tables or sql queries

```

* The best option is to create tables and may insert basic data with a k8s job. See config maps and job in the src/postgresql folder

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

```
```

### Deploy Confluent CP

* Deploy Confluent Kubernetes using the [product documentation](https://docs.confluent.io/operator/current/co-deploy-cfk.html)
* Deploy a Kraft controller, one Kafka broker, and one Schema Registry

```sh
k apply -f basic-kraft-cluster.yaml -n confluent
```


To deploy a Debezium connector, you need to deploy a Kafka Connect cluster with the required connector plug-in(s), before instantiating the actual connector itself.

* Deploy Kafka Connect

```sh
k apply -f kconnect.yaml -n confluent
```

* Perform a port forward to access to the Connect REST API

```sh
k port-forward connect-0 8083:8083 -n confluent
```

* Test list of connectors

```sh
curl -H "Accept:application/json" localhost:8083/connectors/
```

* Deploy debezium

```
```