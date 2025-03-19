# Demonstration of CDC Debezium with Flink

The demonstration is to address:

* Running Postgresql on Kubernetes to define one table for autonomous cars inventory.
* Use Confluent for kubernetes operator and a single node cluster
* Deploying CDC Debezium on Kafka Connect

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