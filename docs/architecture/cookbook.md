# Flink Cookbook

There is a [Github for best practices](https://github.com/confluentinc/flink-cookbook) to run Flink into production as a cookbook. The content of this page is to get a summary with some hands-on exercises for the different Flink deployment environment when it is relevant.

All the examples can be run inside an IDE or in terminal, they are on Flink 1.19.1 and Java 11. Use [sdkman](https://sdkman.io/) to manage different java version. 

## Understand the Flink UI

## Troubleshooting

### A SQL statement not returning any result

This could be linked to multiple reasons so verify the following:

* Verify there is no exception in the statement itself
* Query logic being too restrictive or the joins may not match any records. For aggregation, may be the field used get null values.
* Source table may be empty, or it consumes the table from a different starting offset (specified via `scan.bounded.mode`) then expected.
* Use `show create table <table_name>` to assess the starting offset strategy or specific values
* Count all records in a table using `SELECT COUNT(*) FROM table_name;` , and it should be greater then 0.
* When the statement uses event-time based operation like windowing, top N, OVER, MATCH_RECOGNIZE and temporal joins then verify the watermarks. The following example is from Confluent Cloud for Flink query using the event time from the record, and it should return result. Check if you have produced a minimum of records per Kafka partition, or if the producer has stopped producing data all together.

```sql
SELECT ROW_NUMBER() OVER (ORDER BY $rowtime ASC) AS `number`, *   FROM <table_name>
```

* When Data are in topic but not seen by flink `select * from ` statement, it may be due to idle partitions and the way watermarks advance and are propagated. Flink automatically marks a Kafka partition as idle if no events come within `sql.tables.scan.idle-timeout` duration. When a partition is marked as idle, it does not contribute to the watermark calculation until a new event arrives. Try to set the idle timeout for table scans to ensure that Flink considers partitions idle after a certain period of inactivity. May be try to create a table with a watermark definition to handle idle partitions and ensure that watermarks advance correctly


### Identify which watermark is calculated

Add a virtual column to keep the Kafka partition number by doing:

```sql
ALTER TABLE <table_name> ADD _part INT METADATA FROM 'partition' VIRTUAL;
```

Assess there is a value on the "Operator Watermark" column with

```sql
SELECT
  *,
  _part AS `Row Partition`,
  $rowtime AS `Row Timestamp`,
  CURRENT_WATERMARK($rowtime) AS `Operator Watermark`
FROM  <table_name>;
```

If not all the partitions are in the result, this may be the partitions having the watermark issue. We need to be sure events are send across all partitions. If we want to test a statement, we can also set the statement to not be an unbounded query, but consume until the latest offset by setting: `SET 'sql.tables.scan.bounded.mode' = 'latest-offset';`

Flink statement consumes data up to the most recent available offset at the submission moment. Upon reaching this time, Flink ensures that a final watermark is propagated, indicating that all results are complete and ready for reporting. The statement then transitions into a 'COMPLETED' state."

## Security

## Deduplication

Deduplication is documented [here](../coding/flink-sql.md#table-creation) and [here](https://docs.confluent.io/cloud/current/flink/reference/queries/deduplication.html#flink-sql-deduplication) and at its core principal, it uses a CTE to add a row number, as a unique sequential number to each row. The columns used to de-deplicate are defined in the partitioning and ordering is used using a timestamp to keep the last record.

```sql
SELECT [column_list]
FROM (
   SELECT [column_list],
     ROW_NUMBER() OVER ([PARTITION BY column1[, column2...]]
       ORDER BY time_attr [asc|desc]) AS rownum
   FROM table_name)
WHERE rownum = 1
```

When using Kafka Topic to persist Flink table, it is possible to use the `upsert` change log, and define the primary key(s) to remove duplicate using a CTAS statement:

```sql
CREATE TABLE orders_deduped (
  PRIMARY KEY( order_id, member_id) NOT ENFORCED) DISTRIBUTED BY (order_id, member_id) INTO 1 BUCKETS 
WITH (
  'changelog.mode' = 'upsert',
  'value.fields-include' = 'all'
) AS
SELECT
  *
FROM (
  SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY `order_id`, `member_id`
        ORDER
          BY $rowtime ASC
      ) AS row_num
    FROM
      orders_raw
  )
WHERE
  row_num = 1;
```

Duplicates may still occur on the Sink side, as it is linked to the type of connector used and its configuration. 

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

## Other sources

The current content is sourced from the following cookbooks and lesson learnt while engaging with customers.

* [Confluent Flink Cookbook](https://github.com/confluentinc/flink-cookbook)
* [Ververica Flink cookbook](https://github.com/ververica/flink-sql-cookbook/blob/main/README.md)