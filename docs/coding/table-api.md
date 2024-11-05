# Table API

???- info "Update"
    Created 10/2024 - Updated 11/03/24.

## Concepts

The [TableAPI](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/overview/) serves as the lower-level API for executing Flink SQL, allowing for stream processing in both Java and Python. The Table API encapsulates a stream or physical table, enabling developers to implement streaming processing by programming against these tables.

In the context of **Confluent Cloud**, the Table API acts as a client-side library for interacting with the Flink engine hosted in the cloud. It enables the submission of  `Statements` and retrieval of `StatementResults`. The provided Confluent plugin integrates specific components for configuring the TableEnvironment, eliminating the need for a local Flink cluster. By including the confluent-flink-table-api-java-plugin dependency, Flink's internal components—such as CatalogStore, Catalog, Planner, Executor, and configuration, are managed by the plugin and fully integrated with Confluent Cloud.

## Getting Started

Create a maven project and add the flink table api, and Kafka client dependencies. See [the pom.xml in flink-java/table-api](https://github.com/jbcodeforce/flink-studies/tree/master/flink-java/table-api/pom.xml) folder. For Table API we need at the minimum:

```xml
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-table-api-java</artifactId>
    <version>${flink.version}</version>
</dependency>

<dependency>
    <groupId>io.confluent.flink</groupId>
    <artifactId>confluent-flink-table-api-java-plugin</artifactId>
    <version>1.20-42</version>
</dependency>
```

If we need to connect to Confluent Cloud for Flink we need the  `io.confluent.flink.confluent-flink-table-api-java-plugin`.

When using Confluent Cloud, be sure to define a `cloud.properties` file with the needed properties, such as the flink api key, the environment and compute pool. Do not commit this file into git repo. 

You should better use environment variables and the environment API to load data from those environment variable:

```java
import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.EnvironmentSettings;

EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();
```

### Java

Any main function needs to connect to the Flink environment. ConfluentAPI offers a way to read cloud client properties so the deployed Flink application, on-premises or within a k8s as pod, can access the Job and Task managers running in the Confluent Cloud compute pools:

```java
import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;

public static void main(String[] args) {
    EnvironmentSettings settings = ConfluentSettings.fromResource("/cloud.properties");
    TableEnvironment env = TableEnvironment.create(settings);
```

A [table environment](https://nightlies.apache.org/flink/flink-docs-stable/api/java/org/apache/flink/table/api/TableEnvironment.html) is the base class, entry point, and central context for creating Table and SQL API programs.

See [code sample: Main_00_JoinOrderCustomer.java](https://github.com/jbcodeforce/flink-studies/blob/master/flink-java/table-api/src/main/java/flink/examples/table/Main_00_JoinOrderCustomer.java)

Get the catalog and databases, and use the environment to get the list of tables. In Confluent Cloud, there is a predefined catalog with some table samples: `examples.marketplace`.

```java
# using a sql string
env.executeSql("SHOW TABLES IN `examples`.`marketplace`").print();
# or using the api
env.useCatalog("examples");
env.useDatabase("marketplace");
Arrays.stream(env.listTables()).forEach(System.out::println);
# work on one table
env.from("`customers`").printSchema();
```

The [TableEnvironment](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/TableEnvironment.html) has a lot of helpful functions to connect to external systems, executes SQL statements, or define test data.

## Code Samples

The important classes are:

* [TableEnvironment](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/TableEnvironment.html)
* [Table](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/Table.html)
* [Row](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/types/Row.html)
* [Expressions](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/Expressions.html) contains static methods for referencing table columns, creating literals, and building more complex Expression chains. See below.

### Create some test data

Use one of the TableEnvironment fromValues() methods, below is an example on a collection.

```java
 env.fromValues("Paul", "Jerome", "Peter", "Robert")
                .as("name")
                .filter($("name").like("%e%"))
                .execute()
                .print();
```

```java
import org.apache.flink.table.api.DataTypes;
Table customers = env.fromValues(
                        DataTypes.ROW(
                                DataTypes.FIELD("customer_id", DataTypes.INT()),
                                DataTypes.FIELD("name", DataTypes.STRING()),
                                DataTypes.FIELD("email", DataTypes.STRING())),
                        row(3160, "Bob", "bob@corp.com"),
                        row(3107, "Alice", "alice.smith@example.org"),
                        row(3248, "Robert", "robert@someinc.com"));
```

### Joining two tables

See the example in [00_join_order_customer.java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-java/table-api-java/src/main/java/flink/examples/table/00_join_order_customer.java). The statements may run forever. 

### A deduplication example

The deduplication of record over a time window is a classical pattern. See this SQL query with the following Table API implementation

```java
Table source;
```


### Confluent tools for printing and stop statement

[See this git repository](https://github.com/confluentinc/flink-table-api-java-examples/blob/master/README.md#documentation-for-confluent-utilities)

--- 

### Define data flows

A TablePipeline describes a flow of data from source(s) to sink. We can also use 


The pipeline flow can use different services, defined in separate Java classes. Those classes may be reusable. The environment needs to be passed to each service, as this is the environment which includes all the Table API functions.

Some code is in [this folder](https://github.com/jbcodeforce/flink-studies/tree/master/flink-java/table-api).


## How to

???- question "Create a data generator"
    There is the [FlinkFaker tool](https://github.com/knaufk/flink-faker) that seems to be very efficient to send different types of data. It is using [Datafaker](https://www.datafaker.net/documentation/getting-started/) Java library, which can be extended to add our own data provider. FlinkFaker jar is added to the custom flink image in the Dockerfile. The challenges will be to remote connect to the compute-pool as defined in Confluent Cloud.

???- question "Connect to Confluent Cloud remotely"
    Define the cloud.properties and then use the Confluent API

    ```java
        import io.confluent.flink.plugin.ConfluentSettings;
        import org.apache.flink.table.api.EnvironmentSettings;
        import org.apache.flink.table.api.TableEnvironment;

        public static void main(String[] args) {
            EnvironmentSettings settings = ConfluentSettings.fromResource("/cloud.properties");
            TableEnvironment env = TableEnvironment.create(settings);
    ```

???- question "Create a table with Kafka topic as persistence in Confluent Cloud?"
    ```java
    import io.confluent.flink.plugin.ConfluentSettings;
    import io.confluent.flink.plugin.ConfluentTableDescriptor;
    //...
    env.createTable(
            TARGET_TABLE1,
            ConfluentTableDescriptor.forManaged()
                .schema(
                        Schema.newBuilder()
                                .column("user_id", DataTypes.STRING())
                                .column("name", DataTypes.STRING())
                                .column("email", DataTypes.STRING())
                                .build())
                .distributedBy(4, "user_id")
                .option("kafka.retention.time", "0")
                .option("key.format", "json-registry")
                .option("value.format", "json-registry")
                .build());
    ```

???- question "Access to the schema of an existing topic / table?"
    ```java
    import org.apache.flink.table.api.DataTypes;
    //...
    DataType productsRow = env.from("examples.marketplace.products")
                    .getResolvedSchema()
                    .toPhysicalRowDataType();
    List<String> columnNames = DataType.getFieldNames(productsRow);
    List<DataType> columnTypes = DataType.getFieldDataTypes(productsRow);
    // use in the schema function to create a new topic ...
            Schema.newBuilder()
                    .fromFields(columnNames, columnTypes)
                    .column("additionalColumn", DataTypes.STRING())
                    .build()
    ```

???- question "How to split records to two topic, using StatementSet?"
    ```java
    StatementSet statementSet = env.createStatementSet()
                        .add(
                            env.from("`examples`.`marketplace`.`orders`")
                               .select($("product_id"), $("price"))
                               .insertInto("PricePerProduct"))
                        .add(
                            env.from("`examples`.`marketplace`.`orders`")
                               .select($("customer_id"), $("price"))
                               .insertInto("PricePerCustomer"));
    ```

## Deeper dive

* [See this git repo: Learn-apache-flink-table-api-for-java-exercises](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises). 
* See the [Table API in Java documentation](https://docs.confluent.io/cloud/current/flink/reference/table-api.html).
* [Connecting the Apache Flink Table API to Confluent Cloud](https://developer.confluent.io/courses/flink-table-api-java/exercise-connecting-to-confluent-cloud/) with matching [github](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises) which part of this code was ported into [flink-sql-demos/02-table-api-java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java)