# Table API

???- info "Update"
    - Created 10/2024 
    - Reorganize to improve documentation 10/2025

## Concepts

The [TableAPI](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/overview/) serves as the lower-level API for executing Flink SQL, allowing for stream processing implementations in Java and Python. The Table API encapsulates a stream and physical table, enabling developers to implement streaming processing by programming against these tables.

[See the main concepts](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/common/) and APIs. The structure of a program looks as:

1. Create a TableEnvironment for batch or streaming execution. A [table environment](https://nightlies.apache.org/flink/flink-docs-stable/api/java/org/apache/flink/table/api/TableEnvironment.html) is the base class, entry point, and central context for creating Flink Table and SQL API programs. TableEnvironment uses an `EnvironmentSettings` that define the execution mode.

    === "Apache Flink or Confluent Platform"
    
        ```java title="Apache Flink - Table Environment"
        import org.apache.flink.table.api.EnvironmentSettings;
        import org.apache.flink.table.api.TableEnvironment;
        import org.apache.flink.table.api.EnvironmentSettings;
        import org.apache.flink.table.api.TableEnvironment;

        EnvironmentSettings settings = EnvironmentSettings
            .newInstance()
            .inStreamingMode()
            .withBuiltInCatalogName("default_catalog")
            .withBuiltInDatabaseName("default_database")
            //.inBatchMode()
            .build();
        // Initialize the session context to get started
        TableEnvironment tableEnv = TableEnvironment.create(settings);
        // specific setting
        tableEnv.get_config().set("parallelism.default", "4");
        ```



    === "Confluent Cloud"
        In the context of **Confluent Cloud**, the Table API program acts as a client-side library for interacting with the Flink engine hosted in the cloud.
        Use a specific package to interact with Confluent Cloud via REST api. The integration may be defined in properties, program arguments, or environment variables(recommended)
        ```java title="Connect to Remote Environment"
        import io.confluent.flink.plugin.ConfluentSettings;
        import io.confluent.flink.plugin.ConfluentTools;
        ...
        // With Properties file
        EnvironmentSettings settings = ConfluentSettings.fromResource("/cloud.properties");
        // Env variables:
        EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();
        // With program arguments
        EnvironmentSettings settings = ConfluentSettings.fromArgs(args);
        // Initialize the session context to get started
        TableEnvironment env = TableEnvironment.create(settings);
        ```

* Create one or more source table(s)
    ```java title="Build CTE"
    env.useCatalog(TARGET_CATALOG);
    env.useDatabase(TARGET_DATABASE);
    Table rawTable =  env.from("orders").select(withAllColumns());
    ```

* Create one or more sink Tables(s) or use the print sink:

    === "SQL in TableAPI"
        ```java
        INSERT INTO fct_transactions
        SELECT
            txn_id,
            account_id,
            amount,
            currency,
            `timestamp`,
            status
        FROM src_transactions
        WHERE txn_id IS NOT NULL AND txn_id <> '';
        ```
    === "Pure Table API"
        ```java
        ```

1. Create processing logic using SQL string or Table API functions
1. Package: 
    * For java, using `mvn package` to build a jar 
    * For Python

1. Deploy: Once packaged with maven as a uber-jar the application may be executed locally to send the dataflow to the Confluent Cloud for Flink JobManager or can be deployed as a `FlinkApplication` within a k8s cluster. 

    === "Apache Flink"
        ```sh
        ./bin/flink run ./flink-studies/code/table-api/simplest-table-api-for-flink-oss/target/simplest-table-api-for-flink-oss-1.0.0.jar
        ```

    === "Confluent Platform"
        To be done

    === "Confluent Cloud"
        Execute the program:
        ```sh
        java -jar target/flink-table-api-java-examples-1.0.jar
        ```

### Summary of important concepts:

* The main function is a Flink client, that will compile the code into a dataflow graph and submit to the JobManager.
* A TableEnvironment maintains a map of catalogs of tables 
* Tables can be either virtual (VIEWS) or regular TABLES which describe external data (csv, sql, kafka topic).
* Tables may be temporary (tied to the lifecycle of a single Flink session), or permanent (visible across multiple Flink sessions and clusters).
* Temportary table may shadow a permanent table.
* Tables are always registered with a 3-part identifier consisting of catalog, database, and table name.
* TableSink is a [generic interface to write](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/common/#emit-a-table) results to. A batch Table can only be written to a `BatchTableSink`, while a streaming Table requires either an `AppendStreamTableSink`, a `RetractStreamTableSink`, or an `UpsertStreamTableSink`.
* A pipeline can be explained with `TablePipeline.explain()` and executed invoking `TablePipeline.execute()`.
* Recall that High-Availability in Application Mode is only supported for single-execute() applications.

It is important to note that Table API and SQL queries can be easily integrated with and embedded into DataStream programs.


### Confluent Specifics

In Confluent Platform Manager for Flink deployment, only Flink Application mode is supported. A **Flink Application** is any user's program that spawns one or multiple Flink jobs from its `main()` method. The execution of these jobs can happen in a local JVM (LocalEnvironment) or on a remote setup of clusters with multiple machines ([kubernetes](./k8s-deploy.md)).

In the context of **Confluent Cloud**, the integrate code enables the submission of `Statements` and retrieval of `StatementResults`. The provided Confluent plugin integrates specific components for configuring the TableEnvironment, eliminating the need for a local Flink cluster. By including the `confluent-flink-table-api-java-plugin` dependency, Flink's internal components—such as CatalogStore, Catalog, Planner, Executor, and configuration, are managed by the plugin and fully integrated with Confluent Cloud. This integration is via the REST API, so Confluent Table API plugin is an higher emcapsulation of the CC REST API. 

## Getting Started

### Java
Any main function needs to connect to the Flink environment.

The development approach includes at least the following steps:

1. Create a maven project with a command like:
    ```sh
    mvn archetype:generate -DgroupId=j9r.flink -DartifactId=my-app -DarchetypeArtifactId=maven-archetype-quickstart -DarchetypeVersion=1.5 -DinteractiveMode=false
    ```

1. Add the flink table api, and Kafka client dependencies:

    === "**Open Source Libraries**"
        ```xml
        <groupId>org.apache.flink</groupId>

        <artifactId>flink-java</artifactId>
        <artifactId>flink-clients</artifactId>
        <artifactId>flink-table-api-java</artifactId>
        <artifactId>flink-table-common</artifactId>
        <artifactId>flink-table-api-java-bridge</artifactId>
        <artifactId>flink-table-runtime</artifactId>
        <artifactId>flink-connector-kafka</artifactId>
        <artifactId>flink-connector-base</artifactId>
        <!-- Depending of the serialization needs -->
        <artifactId>flink-json</artifactId>
        <artifactId>flink-avro</artifactId>
        <!-- when using schema registry -->
        <artifactId>flink-avro-confluent-registry</artifactId>
        ```
        (see an example of [pom.xml](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/e-com-sale/flink-app/pom.xml)).  Use `provided` dependencies to get the Flink jars from the deployed product. 

    === "**Confluent Cloud for Flink**"
        Verify [this pom.xml](https://github.com/confluentinc/flink-table-api-java-examples/blob/master/pom.xml) for current supported version.
        ```xml
         <dependency>
            <groupId>io.confluent.flink</groupId>
            <artifactId>confluent-flink-table-api-java-plugin</artifactId>
            <version>${confluent-plugin.version}</version>
        </dependency>
        ```




1. Implement and unit test the flow. 
1. Execute the java program

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

### Python

The Flink Python API communicates with a Java process. You must have at least Java 11 installed, and be sure to have $JAVA_HOME set.

[Python Table API Quick Start on Confluent Cloud for Apache Flink - documentation.](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-python-table-api.html)


## How to

All the Java based Table API examples, for Confluent Cloud are in the []() folder, in different java classes.

### Code structure

Clearly separate the creation of sources, sinks, workflow in different methods. References those methods in the main().

### Joining two tables

```java
Table joinedTable = customers
                        .join(transformedOrders, $("customer_id").isEqual($("o_customer_id")))
                        .dropColumns($("o_customer_id"));
```

### Deduplication

### FAQs
???- question "Create a data generator"
    There is the [FlinkFaker tool](https://github.com/knaufk/flink-faker) that seems to be very efficient to send different types of data. It is using [Datafaker](https://www.datafaker.net/documentation/getting-started/) Java library, which can be extended to add our own data provider. FlinkFaker jar is added to the custom flink image in the Dockerfile. 


???- question "Create a table with Kafka topic as persistence in Confluent Cloud?"
    ```java title="Create a table"
    import io.confluent.flink.plugin.ConfluentSettings;
    import io.confluent.flink.plugin.ConfluentTableDescriptor;
    //...
    env.createTable(
            SINK_TABLE,
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
    ```java title="Access to Table Schema Definition"
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



### Create some test data

Use one of the TableEnvironment fromValues() methods,

=== "From collection"
    ```java
    env.fromValues("Paul", "Jerome", "Peter", "Robert")
                    .as("name")
                    .filter($("name").like("%e%"))
                    .execute()
                    .print();
    ```
=== "With Schema and list of row"
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


### Confluent tools for printing and stop statement

[See this git repository](https://github.com/confluentinc/flink-table-api-java-examples/blob/master/README.md#documentation-for-confluent-utilities)

## References

### APIs
The important classes are:

* [TableEnvironment](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/TableEnvironment.html)
* [Table](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/Table.html)
* [Row](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/types/Row.html)
* [Expressions](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/java/org/apache/flink/table/api/Expressions.html) contains static methods for referencing table columns, creating literals, and building more complex Expression chains. See below.

### Confluent Repositories
* [Confluent Table API Tutorial](//github.com/confluentinc/flink-table-api-java-examples.git)
* [The Confluent Flink cookbook](https://github.com/confluentinc/flink-cookbook) for more Table API and DataStream examples.
* [See this git repo: Learn-apache-flink-table-api-for-java-exercises](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises). 
* See the [Table API in Java documentation](https://docs.confluent.io/cloud/current/flink/reference/table-api.html).
* [Connecting the Apache Flink Table API to Confluent Cloud](https://developer.confluent.io/courses/flink-table-api-java/exercise-connecting-to-confluent-cloud/) with matching [github](https://github.com/confluentinc/learn-apache-flink-table-api-for-java-exercises) which part of this code was ported into [flink-sql-demos/02-table-api-java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/02-table-api-java)

### Flink Experts

* [Timo Walther's flink api examples in Java](https://github.com/twalthr/flink-api-examples)