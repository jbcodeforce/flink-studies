# Confluent Cloud for Apache Flink

[Confluent Cloud for Apache Flink](https://docs.confluent.io/cloud/current/flink/overview.html) is a managed service for Flink cluster in parallel of Kafka cluster managed service.

![](./diagrams/ccloud-flink.drawio.png)

## Key Concepts

* This is a regional service
* Compute pools groups resources needed to run a Flink cluster and can scale to zero. Used to run SQL **statements**. The max size of the pool is set at creation.
* Capacity is measured in Confluent Flink Unit, [CFU](). Each statement is 1 CFU-minute.
* A statement may be structural (DDL), runs in background to write data to table (DML) , or foreground to present data to client app.
* Can support multiple Kafka clusters in the same CC organization within the same region.
* Kafka Topics and schemas are always in synch with Flink.
* Statement in different compute pools are **isolated** from each other. 
* Any table created in CC Flink is visible as a topic in CC Kafka.
* A catalog is a collection of database, a database is a collection of tables.
* The differences with the OSS, is that the DDL statements of catalog, database, table are mapped to physical kafka objects. Table is a schema and a topic, catalog is an environment, and database is a cluster.
* CC offers the **Autopilot** to scale up or down resources for any SQL statement. Scaled up if there is a need to increase resource due to more data.
* Integrated with RBAC with user and service accounts support.
* Stream lineage is a feature to at the topic level to understand where the data are coming from. 
* For Watermark configuration, Confluent Cloud for Apache Flink handles it automatically, using the $rowtime which is mapped to the Kafka record timestamp and by observing the behavior of the streams then adapting the configuration.
* When messages processing starts to be behind, autopilot adjust resource allocation.
* [Service accounts](https://docs.confluent.io/cloud/current/security/authenticate/workload-identities/service-accounts/overview.html#service-accounts) are used for production deployment to enforce security boundaries. Permissions are done with ACL and role binding. They can own any type of API keys that can be used for CLI or API access.

???- info "Statement life cycle"
    Use a service account for background statement.
    Submit a statement:

    ```sh
    confluent flink shell --compute-pool ${COMPUTE_POOL_ID} --environment ${ENV_ID} --service-account
    ```

???- question "How to change the CFU limit?"


## Getting Started

Install the [Confluent CLI](https://docs.confluent.io/confluent-cli/current/overview.html) and get an Confluent Cloud account. 

See those tutorials for getting started.

* [Quickstart with Console](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-cloud-console.html)
* [Apache Flink® SQL](https://developer.confluent.io/courses/flink-sql/overview/)
* [Java Table API Quick Start](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-java-table-api.html)

There is also a new confluent cli plugin: `confluent-flink-quickstart` to create an environment, a compute pool, enable schema registry, create a kafka cluster and starts a Flink shell. 

```sh
confluent flink quickstart --name my-flink-sql --max-cfu 10 --region us-west-2 --cloud aws
```

For study and demonstration there is a read-only catalog named `examples` with database called `marketplace` which is a data generator in SQL tables in memory. 

Set the namespace for queries using:

```sql
use catalog examples;
use marketplace;
show tables;
```

While to map to the created environement we need to:

```sql
use catalog my-flink-sql_environment;
use  my-flink-sql_kafka-cluster;
```

To shutdown every thing:

```sh
confluent environment list
confluent environment delete <ENVIRONMENT_ID>
```

### Some common commands to manage Confluent Cloud environment

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

### Using the Flink editor in Confluent Cloud

### Use Java Table API

The approach is to create a maven Java project with a main class to declare the data flow.  
[See this git repo: Learn-apache-flink-table-api-for-java-exercises](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises). See the [Table API in Java documentation](https://docs.confluent.io/cloud/current/flink/reference/table-api.html).


## Deeper dive

* [Confluent Flink workshop](https://github.com/confluentinc/commercial-workshops/tree/master/series-getting-started-with-cc/workshop-flink) to learn how to build stream processing applications using Apache Flink on Confluent Cloud.
* [Connecting the Apache Flink Table API to Confluent Cloud](https://developer.confluent.io/courses/flink-table-api-java/exercise-connecting-to-confluent-cloud/) with matching [github](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises) which part of this code was ported into [flink-sql-demos/02-table-api-java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java)