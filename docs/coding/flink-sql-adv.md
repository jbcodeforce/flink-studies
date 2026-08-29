# Flink SQL Advanced Topics

## State bootstraping


The Flink stateful function [State Bootstrapping](https://nightlies.apache.org/flink/flink-statefun-docs-master/docs/deployment/state-bootstrap/) helps to load data in Flink snapshot as a way to bootstrap Flink stateful statement.

## Bootstrap Queries

In Confluent Cloud load data from kafka topic or tableflow table, to load historical data then automatically switch to streaming data from Kafka. It leverages [Flink’s HybridSource](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/datastream/hybridsource/) which is a capacity to read data from different bounded sources to a unique input stream. 

### Some constraints

* Reading historical data from Iceberg table do not guaranty the record order (using kafka offset for example). This could affect correctness of query operator like LAST_VALUE, LAG, MATCH_RECOGNIZE. Event-Time dependent operators may experience latent results.
* Reading historical data from Kafka, will keep offset ordering per partition.


