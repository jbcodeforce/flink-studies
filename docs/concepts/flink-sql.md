# Flink SQL Concepts

???- Info "Updates"
    - Created 02/2021 
    - Updated 12/20/24 - Update 11/2025

## Introduction

Flink SQL is an ANSI-compliant SQL engine designed for processing both batch and streaming data on distributed computing servers managed by Flink.

Built on [Apache Calcite](https://calcite.apache.org/), Flink SQL facilitates the implementation of SQL-based streaming logic. With Flink SQL, developers work with **dynamic tables**, a concept similar to materialized views in DB, while abstracting away the stream construct from the developers. 

Developers may write SQL statement, or use the [Table API](https://nightlies.apache.org/flink/flink-docs-release-1.19/docs/dev/table/tableapi/), a language-integrated query API for Java, Scala and Python that enables the composition of queries using relational operators such as selection, filtering, and joining. 

Table API is a client SDK, once submitted to the Job Manager, the code is translated to a Directed Acyclic Graph. SQL or Table API efficiently handle both bounded and unbounded streams within a unified and highly optimized system inspired by traditional databases and SQL.

Both the Table API and SQL operate on top of a lower-level stream operator API, which runs on the dataflow runtime:

<figure markdown="span">
![1](./diagrams/flink-apis.drawio.png){ width=500}
<figcaption>Flink APIs working together</figcaption>
</figure>

The optimizer and planner APIs transform SQL statements for execution across distributed nodes, leveraging the lower-level stream operator API. 

To write and execute SQL queries, developers may package the code in a Java Table API program or use the Flink SQL client: an interactive tool for submitting SQL queries to Flink and visualizing the results. With Confluent Platform or Cloud managed service, SQL is a first language of choices and queries may be submitted via API or CLI as a Statement.

Streams or bounded data are mapped to Tables. The following SQL loads data from a csv file and creates a dynamic table in Flink. The WITH section specifies the properties to external connector to read the stream from:

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

[See the getting started chapter](../coding/getting-started.md) to run Flink open-source locally with the Flink SQL shell client connected to a Job Manager and Task manager running in container. 

[See also the SQL coding practices chapter.](../coding/flink-sql.md)

### Main use cases

Flink SQL can be used in two main categories of application:

1. Reactive application, event-driven function
1. Data as a product with real-time white box ETL pipeline: schematizing, cleaning, enriching for data lake, lake house, feature store or vector store. 

Data engineers are experts on writing SQL for preparing Data as a product, so implementing the same logic on real-time streaming will be easier with an ANSI SQL engine like Flink SQL.

## Parallel with Database SQL

Database applications are typically classified into two domains: Online Transaction Processing (OLTP) and Online Analytical Processing (OLAP), which are used for business reporting.

Databases consist of catalogs, databases, tables, views, and materialized views. The most critical component is the **query processor**, which receives queries, plans their execution using metadata from the catalog (including information about tables and functions), and then executes the query via the storage engine to access the data and generate results.

**Views** are virtual tables derived from the results of SQL queries. Some databases also support **materialized views**, which cache the results in a physical table. For example, a GROUP BY operation on an aggregate can store the results based on grouping elements and aggregates in a new table. Materialized views can be updated through a full refresh (by re-executing the query) or through incremental updates.

Flink SQL utilizes **dynamic tables** derived from data streams and employs materialized views with incremental updates. While it is not a traditional database, Flink functions as a query processor. The processor runs [continuous queries](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/concepts/dynamic_tables/#continuous-queries).
 
In Confluent (Cloud or Platform for Flink), the catalog defines access to the schema registry, and Database reference a Kafka cluster, so Flink SQL engine can access topic message structure to map to Table schema and being able to retrieves records from topics, for processing.

Flink can provide either "exactly once" or "at least once" guarantees (with the possibility of duplicates), depending on the configuration and the external systems used for input and output sources.

For effective "exactly once" processing, the source must be replayable, and the sink must support transactions and being idempotent. Kafka topics support both of these requirements, and the consumer protocol adheres to the read-committed semantics. However, transaction scope in Kafka is at the single-key level, whereas ACID transactions in databases maintain integrity across multiple keys.

## Changelog mode

In traditional DB, changelog, or transaction log, records all modification operations in the database. Flink SQL also generates changelog data: changelogs that contain only INSERT-type events is an **append** streams, with UPDATE events it is an **update** stream.

The changelog `normalize` function allows Flink to track the precise sequence of changes to data, which is essential for all stateful operations. In Kafka, records provide the current state of the records without information of what changed. In Flink, without this state tracking, any stateful operation would produce incorrect or inconsistent results when source records are updated or deleted, as operators would lack the context of how the data has changed. 

Some Flink operations (stateful ones) such as group aggregation and deduplication can produce update events. With retract mode, an update event is splitted into delete and insert events.

???+ warning "State size"
    Queries that make update changes, usually have to maintain more state. See [Flink table to stream conversion](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/concepts/dynamic_tables/#table-to-stream-conversion) documentation.

There are [three different modes](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#changelog-mode) to persist table rows in a append log like a Kafka topic: append, retract or upsert. 

* **append** is the simplest mode where records are only added to the result stream, never updated or retracted. It means that every insertion can be treated as an independent immutable fact. Like a write-once data. Records can be distributed using round robin to the different partitions. Do not use primary key with append, as windowing or aggregation will produce undefined, and may be wrong, results.  [Temporal join](https://developer.confluent.io/courses/flink-sql/streaming-joins/) may be possible. Some query will create append output, like window aggregation, or any operations using the watermark.
    ```sql
    create table if not exists orders (
            order_id STRING primary key not enforced,
            product_id STRING,
            quantity INT
        ) DISTRIBUTED into '1' BUCKETS 
        with (
            'changelog.mode' = 'append',
            'value.fields-include' = 'all'
        );
    ```

    The outcome includes records in topics that are insert, immutable records:

    <figure markdown="span">
    ![1](./images/append-mode-table.png){ width=800 }
    <figcaption>Changelog mode: insert events</figcaption>
    </figure>

    while running the following statement, in a session job, returns the last records per key: (ORD_1, BANANA, 13), (ORD_2, APPLE, 23).
        
    ```sql
    SELECT * FROM `orders` LIMIT 10;
    ```

* **upsert** means that all rows with the same primary key are related and must be partitioned together. Events are only **U**psert or **D**elete for a primary key. Upsert mode needs a primary key. The `changelog.mode` property is set up by using the `WITH ('changelog.mode' = 'upsert')` options when creating the table.
* **retract** means a fact can be undone. Flink emits pairs of retraction (-U) and addition (+U) records. When updating a value, it first sends a retraction of the old record (negative record) followed by the addition of the new record (positive record). It means, a fact can be undone, and the combination of +U and -U are related and must be partitioned together. With retract mode a consumer outside of Flink needs to interpret the Kafka header to implement the good semantic. 

Some operations, such as group by, aggregation and deduplication can produce update events. Use the `EXPLAIN` feature to analyze the physical execution plan of a query to see the changelog mode of each operator. Looking at the physical plan with `EXPLAIN` also specifies the state size used per operator.

[See this lab](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/05-append-log) in this repository, for the different changelog mode study.

Also be sure to get the key as part of the values, using the `'value.fields-include' = 'all'` option, if not it will not be possible to group by the key.

[See the concept of changelog and dynamic tables in Confluent's documentation](https://docs.confluent.io/cloud/current/flink/concepts/dynamic-tables.html).

#### Non-Deterministic Functions with Upsert/Retract Tables

When working with upsert or retract changelog modes, Flink requires deterministic computations to correctly process update messages (`UB`/`UA`/`D` operations). Using non-deterministic functions can cause deployment failures.

**Common Error Messages:**

```sh
generated by non-deterministic function: CURRENT_DATE ) $f10(generated by non-deterministic function: CURRENT_DATE ) can not satisfy the determinism requirement for correctly processing update message('UB'/'UA'/'D' in changelogMode, not 'I' only), this usually happens when input node has no upsertKey(upsertKeys=[{}]) or current node outputs non-deterministic update messages. 
Please consider removing these non-deterministic columns or making them deterministic by using deterministic functions.
```

* **Non-deterministic functions** like `CURRENT_DATE`, `CURRENT_TIMESTAMP`, `NOW()`, `LOCALTIME`, `LOCALTIMESTAMP` return different values each time they're evaluated.
* With **upsert/retract changelog modes**, Flink may need to reprocess the same logical record multiple times (for updates, retractions). If the computation produces different results on reprocessing, the changelog stream becomes inconsistent. This breaks the determinism requirement needed for correct stateful operations.

Replace processing time functions with **event time attributes** like `$rowtime` or explicit event time columns.

As an example:
```sql
SELECT 
  customer_id,
  COUNT(CASE WHEN TIMESTAMPDIFF(DAY, transaction_date, CURRENT_DATE) <= 90 
        THEN 1 END) as transactions_last_90d,
  COUNT(CASE WHEN TIMESTAMPDIFF(DAY, transaction_date, CURRENT_DATE) <= 30 
        THEN 1 END) as transactions_last_30d
FROM upsert_transactions
GROUP BY customer_id;
```

may better work if using the event time:
```sql
SELECT 
  customer_id,
  COUNT(CASE WHEN TIMESTAMPDIFF(DAY, transaction_date, 
        DATE($rowtime)) <= 90 THEN 1 END) as transactions_last_90d,
  COUNT(CASE WHEN TIMESTAMPDIFF(DAY, transaction_date, 
        DATE($rowtime)) <= 30 THEN 1 END) as transactions_last_30d
FROM upsert_transactions
GROUP BY customer_id;
```

As TIMESTAMPDIFF works on DATE, important to use the DATE($rowtime) function to transform the event time to a Date.

#### Other Best Practices

1. **Always use event time** for time-based calculations in streaming pipelines
2. **Extract `$rowtime`** early in your pipeline if you need date comparisons:
   ```sql
   -- In intermediate table
   SELECT 
     *,
     DATE($rowtime) as almost_processing_date
   FROM source_table;
   ```

#### When Processing Time Is Actually Needed

In rare cases where you genuinely need processing time (e.g., for monitoring, debugging), ensure your table uses **append-only mode** (`changelog.mode = 'append'`), not upsert/retract mode.

**Related Considerations:**

- This error only occurs with stateful operations (GROUP BY, JOIN, etc.) that produce upsert/retract streams
- Append-only tables (no primary key, append changelog) can safely use non-deterministic functions
- Event time provides better correctness for streaming analytics and supports late data handling

## SQL Programming Basics

Flink SQL tables are dynamic, meaning they change over time; some tables act more like changelog streams than static tables.

The following diagram illustrates the main processing concepts: the `shipments` table tracks product shipments, while the `inventory` table maintains the current quantity of each item. The INSERT statement processes streams to update the inventory based on new shipment records. This SQL statement uses the SUM aggregation operation to count each item, with the records grouped by item name.

<figure markdown="span">
![](./diagrams/sql-table-stream.drawio.png)
</figure>

SQL is applied directly to the stream of data; data is not stored within Flink. 

Events can represent INSERT, UPDATE, or DELETE operations in the table. The diagram shows that, at the sink level, the initial events reflect the addition of items to the inventory. When the inventory for the "Card" item is updated, a record is first created to remove the current stock of the "Card" and then a new message is sent with the updated stock value (2 cards). This behavior arises from the GROUP BY semantics, where the right table is an update-only table while the left is append-only. 

Dynamic tables can also be persisted in Kafka topics, meaning the table definition includes statements on how to connect to Kafka. In batch processing, the sink can be a database table or a CSV file in the filesystem. 

Note that the SQL Client executes each INSERT INTO statement as a separate Flink job. The STATEMENT SET BEGIN .. END construct can be used to group multiple insert statements into a single set. 

As the job manager schedules these jobs to the task managers, SQL statements are executed asynchronously. For batch processing, developers can set the set `table.dml-sync` option to `true`.

In streaming, the "ORDER BY" statement applies only to timestamps in ascending order, while in batch processing, it can be applied to any type of column.

### Data lifecycle

In a pure Kafka integration architecture, the data lifecycle follows these steps:

* Data is read from a Kafka topic to a Flink SQL table in memory
* Data is processed using Flink SQL statements and may be distributed between multiple hosts.
* Results are returned as result sets in interactive mode, or to a table (mapped to a topic) in continuous streaming mode.

### SQL operators state


| Type | Operators | Comments|
| --- | --- | --- |
| **Stateless** | SELECT {projection, transformation} WHERE {filter}; UNION ..., CROSS JOIN UNNEST or CROSS JOIN LATERAL | Can be distributed |
| **Materialized** | GROUP BY <aggregations>, OVER, JOINS or MATCH_RECOGNIZE | Dangerously Stateful, keep an internal copy of the data related to the query |
| **Temporal** | Time windowed operations, interval **joins**, time-versioned joins | Stateful but constrained in size |

As elements are stored for computing materialized projections, it's crucial to assess the number of elements to retain. Millions to billions of small items are possible. However, if a query runs indefinitely, it may eventually overflow the data store. In such cases, the Flink task will ultimately fail.

In a join any previously processed records can be used potentially to process the join operation on new arrived records, which means keeping a lot of records in memory. As memory will be bounded, there are other mechanisms to limit those joins or aggregation, for example using time windows and time to live parameters.

## Flink SQL High Level FAQ

### Why the watermark is set 7 days in the past?

* Creating a table with the `$rowtime` as watermark like:
    ```sql
    user_id	STRING	NULL,
    -- more columns	 	 
    $rowtime	TIMESTAMP_LTZ(3) *ROWTIME*	NOT NULL	METADATA VIRTUAL, WATERMARK AS `SOURCE_WATERMARK`()	SYSTEM
    ```

* and then checking the watermark value with something like:
    ```sql
    SELECT *, CURRENT_WATERMARK($rowtime) AS current_watermark, $rowtime FROM `table_name`;
    ```

    the current_watermark is 7 days behind. 

Altering the table to use `$rowtime` as watermark addresses the issues. But the default strategy is to emit the first watermark 7 days in the past, if not enough records (1000 records in **each partition**) are emitted. 

[Time and Watermarks video](https://docs.confluent.io/cloud/current/flink/concepts/timely-stream-processing.html)

### How we are going to setup full load of a table?

For Flink SQL stream processing, we assume raw-topics are created from a change data capture systems and continuously write records to the topics. When history is important the raw-topic content become the implementation of the event-sourcing patttern and we need to be able to reprocess from the earliest offset. So when defining the table view associated to this topic, using Flink Kafka connector, the CREATE TABLE has, in the WITH section, a parameter to set the kafka reading strategy: 
    ```sql
    CREATE TABLE raw_user (
          `user_id` BIGINT,
          `name` STRING
    )
    WITH (
          'scan.startup.mode' = 'earliest-offset',
    )
    ```

In Confluent Cloud the connector set this property to the earliest by default. Altering the table can change to the latest-offset.


### How we are going to merge the reference data and CDC data?

This is a standard left or right joins on the fields needed to identify records on both table. The reference data in the context of Kafka is a topic with retention set to infinite, and will all the records in one partition, sorted or not. In Flink a primary key may be defined in the reference table and the changelog model sets to upsert so the last value is kept per key.

## Deeper dive

* [SQL and Table API overview](https://nightlies.apache.org/flink/flink-docs-release-1.15/docs/dev/table/overview/)
* [Table API](https://nightlies.apache.org/flink/flink-docs-release-1.15/docs/dev/table/tableapi/)
* [Introduction to Apache Flink SQL by Timo Walther](https://www.youtube.com/watch?v=oaEkYg56Os4)
* [Flink API examples](https://github.com/twalthr/flink-api-examples) presents how the API solves different scenarios:
    * as a batch processor,
    * a changelog processor,
    * a change data capture (CDC) hub,
    * or a streaming ETL tool