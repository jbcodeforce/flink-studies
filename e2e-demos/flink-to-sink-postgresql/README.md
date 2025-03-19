# Demonstration of Flink to Kafka to Kafka JDBC Sink connector to Postgresql

The goal is to validate how a solution using the following architecture is working and how to validate the results. The Flink statment is joining records from two topics to illustrate stateful and propagation to downstream sink.

![](../../docs/architecture/diagrams/flk-kafka-jdbc-ps.drawio.png)

The use case is a simple transaction system on orders and shipments.

## Approach

* After starting the containers, you can create the input topics and the output topic to verify that the connector is connected correctly. You can use the Kafka Connect REST API to post the configuration:

```bash
curl -X POST -H "Content-Type: application/json" --data @config/sink-connector.json http://localhost:8083/connectors/
```

* Send the data on the two input topics
* Run the Flink SQL dml statement
* Verify enriched orders in the output topic
* Verify records in Postgresql

## Setup

* Start colima with `colima start --cpus 4 --memory 8G --kubernetes`
* As Flink can run on Kubernetes all the demonstration uses open-source flink with kubernetes operator.
* Postgresql runs on k8s with postgresql operator.
