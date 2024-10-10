# Confluent Cloud for Apache Flink

[Confluent Cloud for Apache Flink](https://docs.confluent.io/cloud/current/flink/overview.html) is a managed service for Flink cluster in parallel of Kafka cluster managed service.

![](./diagrams/ccloud-flink.drawio.png)

## Key Concepts

* This is a regional service
* Compute pools groups resources needed to run a Flink cluster and can scale to zero
* Can support multiple Kafka clusters in the same CC organization within the same region.
* kafka Topics and schemas always in synch with Flink
* Any table created in Flink is visible as a topic in kafka
* The differences with the OSS, is that the DDL statements of catalog, database, table are mapped to physical kafka objects. Table is a schema and a topic, catalog is an environment, and database is a cluster
* Integrated with RBAC with user and service accounts support
* A catalog is a collection of database, a database is a collection of tables.
* Stream lineage is a feature to at the topic level to understand where the data are coming from. 

## Getting Started

Install the [Confluent CLI](https://docs.confluent.io/confluent-cli/current/overview.html) and get an account. 

See those tutorials for getting started.

* [Quickstart with Console](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-cloud-console.html)
* [Java Table API Quick Start](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-java-table-api.html)

### Some common ground

```sh
# Create an environment
confluent environment create my_environment --governance-package essentials
# Set the active environment.
confluent environment use <environment id>
# Create a cluster
confluent kafka cluster create my-cluster --cloud gcp --region us-central1 --type basic
# Create Kafka API key
confluent kafka cluster list
export CLID=<kafka cluster id>
confluent api-key create --resource $CLID
# Create a compute pool (adjust cloud and region settings as required).
confluent flink compute-pool create my-compute-pool --cloud gcp --region us-central1 --max-cfu 10
# Create a Flink api key which is scoped in an environment + region pair
confluent api-key create --resource flink --cloud gcp --region us-central1
# Define an api key for schema registry
confluent schema-registry cluster describe
confluent api-key create --resource <schema registry cluster>
# Get the user id
confluent iam user list
```

### Use the Flink SQL shell

Using the confluent cli, we can access to the client via:

```sh
#  
confluent environment list

# Get the compute pool id
confluent flink compute-pool list
# set env variable for pool id and environment id
confluent flink shell --environment $ENVID --compute-pool $CPOOL
```

### Use Java Table API

The approach is to create a maven Java project with a main class to declare the data flow.  
[See this git repo: Learn-apache-flink-table-api-for-java-exercises](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises). See the [Table API in Java documentation](https://docs.confluent.io/cloud/current/flink/reference/table-api.html).


## Deeper dive

* [Confluent Flink workshop](https://github.com/confluentinc/commercial-workshops/tree/master/series-getting-started-with-cc/workshop-flink) to learn how to build stream processing applications using Apache Flink on Confluent Cloud.
* [Connecting the Apache Flink Table API to Confluent Cloud](https://developer.confluent.io/courses/flink-table-api-java/exercise-connecting-to-confluent-cloud/) with matching [github](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises) which part of this code was ported into [flink-sql-demos/02-table-api-java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java)