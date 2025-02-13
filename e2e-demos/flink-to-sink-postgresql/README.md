# Demonstration of Flink to Kafka to Kafka JDBC Sink connector to Postgresql

## Approach

## Setup

* Start docket compose
* After starting the containers, you can create a topic and verify that the connector is working correctly. You can use the Kafka Connect REST API to post the 
configuration:

```bash
curl -X POST -H "Content-Type: application/json" --data @config/sink-connector.json http://localhost:8083/connectors/
```