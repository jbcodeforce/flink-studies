# Flink Cookbook

There is a [Github for best practices](https://github.com/confluentinc/flink-cookbook) to run Flink into production.
All the examples can be run inside an IDE or in terminal, they are on Flink 1.17 and Java 11. Use [sdkman](https://sdkman.io/) to manage different java version. 

## Deduplication

## Change Data Capture

## Late Data

## Exactly once

## Query Evolution

The classical pattern is to consume streams from Kafka Topics and then add different stateful processing using Flink SQL, Table API or DataStreams. The question is **when we need to stop such processing how to restart them?**. We have seen the [stateful processing](../index.md/#stateful-processing) leverages checkpoints and savepoints. Developers need to enable checkpointing and manually triggering a savepoint when needed to restart from a specific point in time.

When a SQL statement is started, it reads the source tables from the beginning (or any specified offset). It also uses the latest schema version for key and value.

The common practice, developers replace existing statement and tables with a new statement and new tables using CTAS. Once the statement started, wait for the new statement to get the latest messages of the source tables, then migrate existing consumers to the new table. It is possible to start from a specific offset or a specific timestamp. Reading back from an offset will work for stateless statements only to ensure exactly-once delivery.

It is possible to do an in-place upgrade if the table use primary key.

Restarting a job is not a retry mechanism but a fault tolerance one. Normally only cluster level issues should ever cause a job to restart. When doing Java or Python application, developers need to do not throw exceptions within the main function but handle them and perform retries, backoff, and loop forever. as part of the exception management it is important to provide diagnostic data to administrators.

When integrated with Kafka, networking latency may trigger losing connection, or some user errors like deleting the cluster, a topic, a connector... may make the job getting in retry loop. 

Savepoints are manually triggered snapshots of the job state, which can be used to upgrade a job or to perform manual recovery.

Full checkpoints and savepoints take a long time, but incremental checkpoints are faster.

### Confluent Cloud for Flink

[See this product documentation](https://docs.confluent.io/cloud/current/flink/concepts/schema-statement-evolution.html) for details about what can be changed in a SQL statement. 

#### Demonstrate in-place upgrade of stateless statement

#### Demonstrate stateful statement upgrade

### Flink on Kubernetes

* To trigger a savepoints do: 
* 

## Measuring Latency 