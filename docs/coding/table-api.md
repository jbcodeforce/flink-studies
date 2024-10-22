# Table API

???- info "Update"
    Created 10/2024

## Concepts

The TableAPI is the lower level API used for doing Flink SQL. So it is possible to use it in Java or Python to do the stream processing. The Table is an encapsulation of a stream or a physical table, and so streaming processing implementation is programming against tables.

## Getting Started

Create a maven project and add the flink table api dependencies. See [the pom.xml in flink-sql-demos/02-table-api-java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java).

### Java

Any main function needs to connect to the Flink environment. ConfluentAPI offers a way to read cloud client properties so the deployed Flink application on-premises or within a k8s as pod, can access the Job and Task managers:

```java
import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;

public static void main(String[] args) {
    EnvironmentSettings settings = ConfluentSettings.fromResource("/cloud.properties");
    TableEnvironment env = TableEnvironment.create(settings);
```

* Get the catalog and databases, and use the environment to get the list of tables. In Confluent Cloud there are a set of predefined catalog and tables: `examples.marketplace`.

```java
    env.useCatalog("examples");
    env.useDatabase("marketplace");

    Arrays.stream(env.listTables()).forEach(System.out::println);
```

The the pipeline flow can use different services, defined in separate Java classes. Those classes may be reusable. The environment needs to be passed to each service, as this is the environment which includes all the Table API functions.

The completed code of the [Confluent training]() is in [this folder](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java).

### With Confluent Cloud and API

## Code Examples

## How to

???- question "Create a data generator"
    There is the [FlinkFaker tool](https://github.com/knaufk/flink-faker) that seems to be very efficient to send different types of data. It is using [Datafaker](https://www.datafaker.net/documentation/getting-started/) Java library, which can be extended to add our own data provider. FlinkFaker jar is added to the custom flink image in the Dockerfile. The challenges will be to remote connect to the compute-pool as defined in Confluent Cloud.

???- question "Connect to Confluent Cloud remotely"



## Deeper dive