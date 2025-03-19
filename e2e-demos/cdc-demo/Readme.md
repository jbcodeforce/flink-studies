# Demonstration of CDC Debezium with Flink

The demonstration is to address:

* Running Postgresql on Kubernetes to define one table for autonomous cars inventory.
* Use Confluent for kubernetes operator and a single node cluster
* Deploying CDC Debezium on Kafka Connect

See [Debezium PostgreSQL Source Connector for Confluent Platform](https://docs.confluent.io/kafka-connectors/debezium-postgres-source/current/overview.html).

## Setup

* Create the PG Cluster

```sh
k apply infrastructure/pg-cluster.yaml
```

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