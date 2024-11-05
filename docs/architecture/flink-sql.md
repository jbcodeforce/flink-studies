# Flink SQL and Table API

???- Info "Updates"
    - Created 02/2021 
    - Modified 11/3/24

## Introduction

Flink SQL is an ANSI-compliant SQL engine designed for processing both batch and streaming data on distributed computing servers managed by Flink.

Built on [Apache Calcite](https://calcite.apache.org/), Flink SQL facilitates the implementation of SQL-based streaming logic. It utilizes the [Table API](https://nightlies.apache.org/flink/flink-docs-release-1.19/docs/dev/table/tableapi/), a language-integrated query API for Java, Scala, and Python that enables the composition of queries using relational operators such as selection, filtering, and joining.

The Table API efficiently handles both bounded and unbounded streams within a unified and highly optimized ecosystem inspired by traditional databases and SQL.

Both the Table API and SQL operate on top of a lower-level stream operator API, which runs on the dataflow runtime:

![](./diagrams/flink-apis.drawio.png){ width=500}

The optimizer and planner APIs transform SQL statements for execution across distributed nodes, leveraging the lower-level stream operator API.With Flink SQL, we work with **dynamic tables**, a concept similar to materialized views, while abstracting away the stream construct from the developer.You can write SQL and use the Table API in Java, Scala, or Python, or leverage the SQL client, an interactive tool for submitting SQL queries to Flink and visualizing the results.

Stream or bounded data are mapped to Table. The following command loads data from a csv file and [creates a dynamic table](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html) in Flink:

```sql
CREATE TABLE car_rides (
    cab_number VARCHAR,
    plate VARCHAR, 
    cab_type VARCHAR,
    driver_name VARCHAR, 
    ongoing_trip VARCHAR, 
    pickup_location VARCHAR, 
    destination VARCHAR, 
    passenger_count INT
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql-quarkus/data/cab_rides.txt',
    'format' = 'csv'
);
```

Show how the table is created:

```sql
show create table orders;
```

[See the getting started](../coding/getting-started.md) to run locally with a sql client connected to a Job Manager and Tsk manager running in docker.

### Main use cases

Flink and Flink SQL can be used in two main categories of application:

1. Reactive application, event-driven
1. Data products with real-time white box ETL pipeline: schematizing, cleaning, enriching for data lake, lake house, feature store or vector store. 

## Parallel with Database

Database applications are typically classified into two domains: Online Transaction Processing (OLTP) and Online Analytical Processing (OLAP), which are used for business reporting.

Databases consist of catalogs, databases, tables, views, and materialized views. The most critical component is the query processor, which receives queries, plans their execution using metadata from the catalog (including information about tables and functions), and then executes the query via the storage engine to access the data and generate results.

**Views** are virtual tables derived from the results of SQL queries. Some databases also support **materialized views**, which cache the results in a physical table. For example, a GROUP BY operation on an aggregate can store the results based on grouping elements and aggregates in a new table. Materialized views can be updated through a full refresh (by re-executing the query) or through incremental updates.

Flink SQL utilizes dynamic tables derived from data streams and employs materialized views with incremental updates. While it is not a traditional database, Flink functions as a query processor. In Confluent Cloud, the catalog accesses the schema registry for a topic, and query execution occurs on a Flink cluster that retrieves records from topics.

Flink can provide either "exactly once" or "at least once" guarantees (with the possibility of duplicates), depending on the configuration and the external systems used for input and output tables.

For effective "exactly once" processing, the source must be replayable, and the sink must support transactions. Kafka topics support both of these requirements, and the consumer protocol adheres to the read-committed semantics. However, transaction scope in Kafka is at the single-key level, whereas ACID transactions in databases maintain integrity across multiple keys.

## SQL Programming Basics

Flink SQL tables are dynamic, meaning they change over time; some tables act more like changelog streams than static tables.

The following diagram illustrates the main processing concepts: the `shipments` table tracks product shipments, while the `inventory` table maintains the current quantity of each item. The INSERT statement processes streams to update the inventory based on new shipment records. This SQL statement uses the SUM aggregation operation to count each item, with the items shuffled to group them by type.

![](./diagrams/sql-table-stream.drawio.png)

SQL is applied directly to the stream of data; data is not stored within Flink. Events can represent INSERT, UPDATE, or DELETE operations in the table. The diagram shows that, at the sink level, the initial events reflect the addition of items to the inventory. When the inventory for the "Card" item is updated, a record is first created to remove the current stock of the "Card" and then a new message is sent with the updated stock value (2 cards). This behavior arises from the GROUP BY semantics, where the right table is an update-only table while the left is append-only. Dynamic tables can also be persisted in Kafka topics, meaning the table definition includes statements on how to connect to Kafka. In batch processing, the sink can be a database table or a CSV file in the filesystem. 

Note that the SQL Client executes each INSERT INTO statement as a separate Flink job. The STATEMENT SET command can be used to group multiple insert statements into a single set. As the job manager schedules these jobs to the task managers, SQL statements are executed asynchronously. For batch processing, developers can set the set `table.dml-sync` option to `true`.

In streaming, the "ORDER BY" statement applies only to timestamps in ascending order, while in batch processing, it can be applied to any record field.


### Data lifecycle

In a pure Kafka integration architecture, such as Confluent Cloud, the data lifecycle follows these steps:

* Data is read from a Kafka topic to a Flink SQL table.
* Data is processed using SQL statements.
* Results are returned as result sets in interactive mode, or to a table (mapped to a topic) in continuous streaming mode.

### Some SQL operators

| Type | Operators | Comments|
| --- | --- | --- |
| **Stateless** | SELECT <projection | transformation> WHERE <filter> | Can be distributed |
| **Materialized** | GROUP BY <aggregationss> or JOINS | Dangerously Stateful, keep an internal copy of the data related to the query |
| **Temporal** | time windowed operations, interval **joins**, time-versioned joins, MATCH_RECOGNIZE <pattern> | Stateful but contrained in size |

As elements are stored for computing materialized projections, it's crucial to assess the number of elements to retain. Millions to billions of small items are possible. However, if a query runs indefinitely, it may eventually overflow the data store. In such cases, the Flink task will ultimately fail.

Below is an example of Join query:

```sql
SELECT transactions.amount, products.price
FROM transactions
JOIN products
ON transactions.product_id = products.id
```

Any previously processed records can be used potentially to process the join operation on new arrived records, which means keeping a lot of records in memory. As memory will be bounded, there are other mechanisms to limit those joins or aggregation, for example using time windows.


---

## Lower level Java based programming model

* Start Flink server using docker ([start with docker compose](../coding/getting-started.md#docker-compose-with-kafka-and-flink) or on [k8s](../coding/k8s-deploy.md)). 
* Start by creating a java application (quarkus create app for example or using maven) and a Main class. See code in [flink-sql-quarkus](https://github.com/jbcodeforce/flink-studies/blob/master/flink-sql/flink-sql-quarkus/) folder.
* Add dependencies in the pom

```xml
      <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-table-api-java-bridge</artifactId>
        <version>${flink-version}</version>
      </dependency>
        <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-table-runtime</artifactId>
        <version>${flink-version}</version>
        <scope>provided</scope>
      </dependency>
      <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-table-planner-loader</artifactId>
        <version>${flink-version}</version>
        <scope>provided</scope>
      </dependency>
```



```java

public class FirstSQLApp {
 public static void main(String[] args) {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);
```

The `TableEnvironment` is the entrypoint for Table API and SQL integration. See [Create Table environment](https://nightlies.apache.org/flink/flink-docs-release-1.19/docs/dev/table/common/#create-a-tableenvironment)

A TableEnvironment maintains a map of catalogs of tables which are created with an identifier. Each identifier consists of 3 parts: catalog name, database name and object name.


```java
    // build a dynamic view from a stream and specifies the fields. here one field only
    Table inputTable = tableEnv.fromDataStream(dataStream).as("name");

    // register the Table object in default catalog and database, as a view and query it
    tableEnv.createTemporaryView("clickStreamsView", inputTable);
```

![](./diagrams/sql-concepts.drawio.png)


Tables can be either temporary, tied to the lifecycle of a single Flink session, or permanent, making them visible across multiple Flink sessions and clusters.

Queries such as SELECT ... FROM ... WHERE which only consist of field projections or filters are usually stateless pipelines. However, operations such as joins, aggregations, or deduplications require keeping intermediate results in a fault-tolerant storage for which Flink’s state abstractions are used.


### ETL with Table API

See code: [TableToJson](https://github.com/jbcodeforce/flink-studies/blob/master/flink-sql-quarkus/src/test/java/org/acme/TableToJson.java)

```java
public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment streamEnv = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(streamEnv);

        final Table t = tableEnv.fromValues(
                
            row(12L, "Alice", LocalDate.of(1984, 3, 12)),
            row(32L, "Bob", LocalDate.of(1990, 10, 14)),
            row(7L, "Kyle", LocalDate.of(1979, 2, 23)))
        .as("c_id", "c_name", "c_birthday")
        .select(
                jsonObject(
                JsonOnNull.NULL,
                    "name",
                    $("c_name"),
                    "age",
                    timestampDiff(TimePointUnit.YEAR, $("c_birthday"), currentDate())
                )
        );

        tableEnv.toChangelogStream(t).print();
        streamEnv.execute();
    }
```

### Join with a kafka streams

Join transactions coming from Kafka topic with customer information.

```java
    // customers is reference data loaded from file or DB connector
    tableEnv.createTemporaryView("Customers", customerStream);
    // transactions come from kafka
    DataStream<Transaction> transactionStream =
        env.fromSource(transactionSource, WatermarkStrategy.noWatermarks(), "Transactions");
    tableEnv.createTemporaryView("Transactions", transactionStream
    tableEnv
        .executeSql(
            "SELECT c_name, CAST(t_amount AS DECIMAL(5, 2))\n"
                + "FROM Customers\n"
                + "JOIN (SELECT DISTINCT * FROM Transactions) ON c_id = t_customer_id")
        .print();
```

## Challenges

* We cannot express everything in SQL but we can mix Flink Stream and Table APIs

## Read more

* [SQL and Table API overview](https://nightlies.apache.org/flink/flink-docs-release-1.15/docs/dev/table/overview/)
* [Table API](https://nightlies.apache.org/flink/flink-docs-release-1.15/docs/dev/table/tableapi/)
* [Flink API examples](https://github.com/twalthr/flink-api-examples) presents how the API solves different scenarios:

    * as a batch processor,
    * a changelog processor,
    * a change data capture (CDC) hub,
    * or a streaming ETL tool