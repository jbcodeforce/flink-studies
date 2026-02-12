# Create Table SQL (DDLs)

???- Info "Updates"
    Created 10/24, Updated 12/20/24
    Revised 12/06/24

This chapter offers a compilation of best practices for implementing Flink SQL solutions, applicable to local Flink open-source, the Confluent Platform for Flink or the Confluent Cloud for Flink.

Data Definition Language (DDL) are statements to define metadata in Flink SQL by creating, updating, or deleting tables. [See the Flink SQL Examples in Confluent Cloud for Apache Flink documentation.](https://docs.confluent.io/cloud/current/flink/reference/sql-examples.html#flink-sql-examples-in-af-long)

A table registered with the CREATE TABLE statement can be used as a table source or a table sink.

Create table statements do not changes between managed services and standalone Flink deployment, except the metadata. Each examples with specific standalone content, will be marked as Flink OSS, which also works for Confluent Platform Flink.

## Sources Of Information

* [Confluent SQL documentation for DDL](https://docs.confluent.io/cloud/current/flink/reference/statements/overview.html)  with [useful examples](https://docs.confluent.io/cloud/current/flink/reference/sql-examples.html).
* [Apache Flink CREATE SQL](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sql/create/)
* [Confluent Developer Flink tutorials](https://developer.confluent.io/tutorials/)
* [See SQL examples from product documentation.](https://docs.confluent.io/cloud/current/flink/reference/sql-examples.html)

[Create table syntax](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sql/create/#create-table)

## Common Principles

* Primary key can have one or more columns, all of them should be not null, and only being `NOT ENFORCED`
* Inside Flink processing, the primary key declaration, partitions the table implicitly by the key column(s)
* Flink uses the primary key for state management and deduplication with upsert. While the partition key is what determines which Kafka partition a message will be written to. This is a Kafka-level concept.
* For upsert mode, the bucket key must be equal to primary key. While for append/retract mode, the bucket key can be a subset of the primary key. [See more on changelog.mode](../concepts/flink-sql.md/#changelog-mode)

* Understanding the table structure and mapping from a Kafka topic: the basic query helps a lot to understand table configuration and column types. This is helpful to assess time column, to confirm if the type of a column as event_time is a STRING, TIMESTAMP or TIMESTAMP_LTZ.

    ```sql
    show create table
    ```

    The `TYPEOF(column_name)` can also being used in a select to understand the type, and troubleshooting a type error.

* Understand the execution plan of a query using `EXPLAIN insert or select`, helps to assess if the query supports the expected semantic like window aggregation, interval joins or classical joins. The change to append to retract or upsert is also very important for state assessment. Recall that properties of the destination table will influence the plan. 

## Table Creation How-Tos

### Confluent Cloud Specifics

* In Confluent Cloud, partition key will generate a key schema, except if using the option (`'key.format' = 'raw'`)
* If the destination topic doesn't define partitioning key, then CC Flink SQL will write the records in whatever partitioning that was used at the end of the query. if last operation in the query is `GROUP BY foo` or `JOIN ON A.foo = B.foo`, then output records would be partitioned on `foo` values, and they wouldn't be re-partitioned before writing them into Kafka. The `foo` partitioning is preserved. 

???+ tip "Primary key and partition by considerations"
    * If you have parallel queries without any data shuffling, like `INSERT INTO Table_A SELECT * FROM Table_B`, then any skew from Table_B would be repeated in Table_A. Otherwise, if partitioning key is defined (like `DISTRIBUTED BY HASH(metric) `), any writes into that topic would be shuffled by that new key.
    * In case of key skew, add more fields in the distribution to partition not just in one key. That would allow Flink to read data in more parallel fashion, improving the problem with readings from Kafka's bottleneck of 18MBs/connection (partition)
    * An interesting metric for Confluent Cloud Flink, 5 partitions feeds 1 CFU. CFU has constraint on memory and cpu.
    * The performance bottleneck will be actually records serialization and deserialisation, avro is slower than protobuf.

    ```sql
    -- simplest table
    CREATE TABLE humans (race STRING, origin STRING);
    -- with primary key 
    CREATE TABLE manufactures (m_id INT PRIMARY KEY NOT ENFORCED, site_name STRING);
    -- with hash distribution to 2 partitions that match the primary key
    CREATE TABLE humans (hid INT PRIMARY KEY NOT ENFORCED, race STRING, gender INT) DISTRIBUTED BY (hid) INTO 2 BUCKETS;
    ```

???- question "How to read all records from topic (at least once)?"
    Create the table with the property
    ```sql
    CREATE TABLE all_tx (
        ....
    )
      WITH(
        'kafka.consumer.isolation-level'='read-uncommitted',
        ...)
    ```

    For exactly once the parameter is set to `'read-committed'`.

???- question "How to pass comment from table creation to schema definition doc field?"
    Using `COMMENT` at the column level will populate the doc field. Here is an example:
    ```sql
    create table person (
        lastname STRING COMMENT 'the last name of the person',
        firstname STRING COMMENT 'the first name of the person',
        dob STRING COMMENT 'the date of birth'
    )
    ```

    And the schema has the doc populated for each field
    
    ```json
    {
    "fields": [
        {
        "default": null,
        "doc": "the last name of the person",
        "name": "lastname",
        "type": [
            "null",
            "string"
        ]
        },
        {
        "default": null,
        "doc": "the first name of the person",
        "name": "firstname",
        "type": [
            "null",
            "string"
        ]
        },
        {
        "default": null,
        "doc": "the date of birth",
        "name": "dob",
        "type": [
            "null",
            "string"
        ]
        }
    ],
    "name": "person_value",
    "namespace": "org.apache.flink.avro.generated.record",
    "type": "record"
    }
    ```

### Flink OSS

???+ tip "Create a table with csv file as persistence - Flink OSS"
    We need to use the file system connector.

    ```sql
    create table user (
        'user_id' VARCHAR(250),
        'name' VARCHAR(50)
    ) partitioned by ('used-id')
    WITH (
        'format' = 'json', -- other format are: csv, parquet
        'connector' = 'filesystem',
        'path' = '/tmp/users'
    );
    ```


???+ question "How to consume from a Kafka topic to a SQL table? -- Flink OSS"
    On Confluent Cloud for Flink, there are already tables created for each topic. For local Flink we need to create table with column definitions that maps to attributes of the record. The `From` right operand proposes the list of topic/table for the catalog and database selected. For Flink OSS or Confluent Platform for Flink the `WITH` statement helps to specify the source topic.

    ```sql
    select .... from TableName 
    WITH (
        'connector' = 'kafka',
        'topic' = 'flight_schedules',
        'properties.bootstrap.servers' = 'localhost:9092',
        'properties.group.id' = 'fs_grp',
        'scan.startup.mode' = 'earliest-offset',
    )
    ```

    For Avro and schema registry with open source Flink. See the tool [extract_sql_from_avro.py](https://github.com/jbcodeforce/flink-studies/blob/master/tools/extract_sql_from_avro.py) to query Confluent Schema Registry and build the matching SQL to create a table connected to the topic using this schema.

    ```sql
    CREATE TABLE shoe_customers (
        id STRING,
        first_name STRING,
        last_name STRING,
        email STRING,
        phone STRING,
        street_address STRING,
        state STRING,
        zip_code STRING,
        country STRING,
        country_code STRING
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'shoe_customers',
        'properties.bootstrap.servers' = 'broker:29092',
        'scan.startup.mode' = 'earliest-offset',
        'key.format' = 'raw',
        'key.fields' = 'id',
        'value.format' = 'avro-confluent',
        'properties.group.id' = 'flink-sql-consumer',
        'value.fields-include' = 'ALL',
        'value.avro-confluent.url' = 'http://schema-registry:8081'
    );
    ```

 

???+ question "How to load data from a csv file using filesystem connector using SQL - Flink OSS"
    Enter the following statement in a SQL client session:

    ```sql
    SET execution.runtime-mode=BATCH;
    ```
    Create a table from the content of the file, mounted inside the container or accessible on local file system:

    ```sql
    CREATE TABLE employee_info (
        emp_id INT,
        name VARCHAR,
        dept_id INT
    ) WITH ( 
        'connector' = 'filesystem',
        'path' = '/home/flink-sql-demos/00-basic-sql/data/employees.csv',
        'format' = 'csv'
    );
    ```

    Show tables and list some elements within the table.
    
    ```sql
    SHOW TABLES;

    SELECT * from employee_info WHERE dept_id = 101;
    ```

    Show how the table is created:

    ```sql
    show create table orders;
    ```

    [See complete example in the readme](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/00-basic-sql)


???+ question "How to add a metadata field in a table?"
    [Use ALTER TABLE](https://docs.confluent.io/cloud/current/flink/reference/statements/alter-table.html) to modify existing table. Below is an example of adding dt attribute.
    
    ```sql
    alter table flight_schedules add(dt string metadata virtual);
    ```


???+ tip "Create a table as another table by inserting all records (CTAS create table as select)"
    [CREATE TABLE AS SELECT](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#create-table-as-select-ctas) is used to create table and insert values in the same statement. It derives the physical column data types and names (from aliased columns), the changelog.mode (from involved tables, operations, and upsert keys), and the primary key.
    
    By using a primary key:

    ```sql
    create table shoe_customer_keyed(
        primary key(id) not enforced
    ) distributed by(id) into 1 buckets
    as select id, first_name, last_name, email from shoe_customers;
    ```

???+ question "How to support nested rows, DDL and inserts?"
    Avro, Protobuf or Json schemas are very often hierarchical per design. ROW and ARRAY are the objects with nested elements.
    `StatesTable` is a column in table `t`. It has rows of `states` column which is itself a array of `name,city,lg,lat`.
    ```sql
    -- DDL
    create table t (
        StatesTable ROW< states ARRAY<ROW<name STRING, city STRING, lg DOUBLE, lat DOUBLE>>>,
        creationDate STRING
    )

    insert into t(group_id, StatesTable,creationDate)
    values( 
        'grp_1',
        (
        ARRAY[ row('California', 'San Francisco', -122.4194, 37.7749),
            row('New York', 'New York City', -74.0060, 40.7128),
            row('Texas', 'Austin', -97.7431, 30.2672)
        ]
        ),            -- StatesTable
        '2020-10-10'  -- creationDate
    )
    ```

???+ question "How to support nested rows, and inserts from previous table definition?"
    From previous table definition, to extract lat and long:

    ```sql
    select
    group_id,
    -- example of defining attribute from the idx element of an array (starts from 1) from a nested schema:
      CAST(StatesTable.states[3] AS DECIMAL(10, 4)) AS longitude,
      CAST(StatesTable.states[4] AS DECIMAL(10, 4)) AS latitude
    from t
    -- results
     'grp_1', -122.4194, 37.7749
     'grp_1', -74.0060, 40.7128
     'grp_1', -97.7431, 30.2672
    ```

    See also the [CROSS JOIN UNNEST](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sql/queries/joins/#array-expansion) keywords.

    See also a running demo in [flink-sql/03-nested-row](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/03-nested-row)


???+ question "How to generate data using Flink Faker? (Flink OSS)"
    Create at table with records generated with [Flink faker](https://github.com/knaufk/flink-faker) connector using the [DataFaker expressions.](https://github.com/datafaker-net/datafaker). 

    ```sql
    CREATE TABLE `bounded_pageviews` (
      `url` STRING,
      `user_id` STRING,
      `browser` STRING,
      `ts` TIMESTAMP(3)
    )
    WITH (
      'connector' = 'faker',
      'number-of-rows' = '500',  -- or null for infinite
      'rows-per-second' = '100',
      'fields.url.expression' = '/#{GreekPhilosopher.name}.html',
      'fields.user_id.expression' = '#{numerify ''user_##''}',
      'fields.browser.expression' = '#{Options.option ''chrome'', ''firefox'', ''safari'')}',
      'fields.ts.expression' =  '#{date.past ''5'',''1'',''SECONDS''}'
    );
    ```
    
    Attention on Confluent Cloud, this is a connector, there is no marching Kafka Topic created. The faker will run as part of the platform and use resources. Better to drop the table once demonstrations are done.

???- info "Deeper dive into Faker Connector"
    **flink-faker** is a specialized table source that bridges Apache Flink’s SQL engine with the Java DataFaker. It acts as a ScanTableSource. It creates an internal generator that produces rows on-the-fly. Each column is mapped to a "Faker expression" using the syntax #{className.methodName 'parameter'}. By default, it generates an infinite stream of data. You can make it "bounded" (stop after a certain number of rows) for batch-style testing.

    | Field operation | Description |
    | --- | --- |
    | Time-based generation | Give a strings that Flink can parse into TIMESTAMP(3): 'fields.ts.expression' = '#{date.past ''15'',''SECONDS''}' |
    | categorical values | 'fields.status.expression' = '#{Options.option ''PENDING'',''SHIPPED'',''CANCELLED''}' |
    | Regex specific pattern | 'fields.zip_code.expression' = '#{regexify ''[0-9]{5}-[0-9]{4}''}' |
    | Nested json via row |  ... details ROW<item_name STRING, price DOUBLE> ) WITH ( 'connector' = 'faker', 'fields.details.item_name.expression' = '#{commerce.productName}', 'fields.details.price.expression' = '#{commerce.price}'| 

    See [This test sql for the transaction processing](https://github.com/jbcodeforce/flink_project_demos/tree/main/tx_processing/pipelines/sources/tx/src_transactions/tests/dml_faker.sql)




???+ info "Generate data with DataGen for Flink OSS"
    [Use DataGen to do in-memory data generation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/datagen/) and the [new feature in product how to guide documentation](https://docs.confluent.io/cloud/current/flink/how-to-guides/custom-sample-data.html#flink-sql-custom-sample-data).

???+ question "How to generate test data to Confluent Cloud Flink?"
    Use Kafka Connector with DataGen. Those connector exists with a lot of different pre-defined model. Also it is possible to define custom Avro schema and then use predicates to generate data. There is a [Produce sample data quick start tutorial from the Confluent Cloud home page](https://docs.confluent.io/cloud/current/connectors/cc-datagen-source.html). See also [this readme](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/01-kafka-flink).

    The [Shift_left tool](https://jbcodeforce.github.io/shift_left_utils/coding/test_harness/#usage-and-recipe) has also a test harness to generate synthetic data taking into account the SQL content.

???+ question "How to transfer the source timestamp to another table"
    As $rowtime is the timestamp of the record in Kafka, it may be interesting to keep the source timestamp for the downstream tables.

    ```sql
    create table `some_clicks` (
          `order_id` STRING NOT NULL,
          ...
          `event_time` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'),
          PRIMARY KEY(order_id) NOT ENFORCED
    distributed by hash(order_id) into '4' buckets
    ```

    Then the statement to insert record to the new table:
    
    ```sql
    insert into `some_clicks`
    select
        order_id, 
        user_id,
        $rowtime as event_time
    from  `src_table`;
    ```

???+ info "Views over Tables"
    Recall [views](https://docs.confluent.io/cloud/current/flink/reference/statements/create-view.html), are read-only, and have no insert operation and are used to encapsulate complex queries and reference them like regular tables. It acts as a virtual table that refers to the result of the specified statement expression. They are read-only. 
    
    ```sql
    CREATE VIEW IF NOT EXISTS table_view AS SELECT ...
    ```
    
    Views and tables share the same namespace in Flink. [See array of row view example](https://github.com/jbcodeforce/flink-studies/blob/master/code/flink-sql/03-nested-row/vw.array_of_rows.sql).

???+ question "Dealing with late event"
    Any streams mapped to a table have records arriving more-or-less in order, according to the `$rowtime`, and the watermarks let the Flink SQL runtime know how much buffering of the incoming stream is needed to iron out any out-of-order-ness before emitting the sorted output stream.

    We need to  specify the watermark strategy: for example within 30 second of the event time: 

    ```sql
    create table new_table (
        ....
        `event_time` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp',
     watermark for `event_time` as `event_time` - INTERVAL '30' SECOND
    );
    ```

    Event_time could be a ts from the source table (like CDC table). On CCF, the watermark is on the `$rowtime` by default, but it can be changed. 

???+ question "How to change system watermark?"
    Modify the WATERMARK metadata using alter table.

    ```sql
    ALTER TABLE table_name MODIFY WATERMARK FOR $rowtime AS $rowtime - INTERVAL '1' SECOND;
    -- in case we need to reverse back
    ALTER TABLE table_name DROP WATERMARK;
    ```

    This can be used when doing enrichment join on reference table. We do not want to wait for watermark arriving on the reference table, so set the watermark of this reference table to the max INT using `ALTER TABLE table_name SET `$rowtime` TO_TIMESTAMP(,0)`

???+ question "Create a table with topic as one day persistence"
    See the [WITH options](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#with-options).

    ```sql
    create table `small-orders` (
        `order_id` STRING NOT NULL,
        `customer_id` INT NOT NULL,
        `product_id` STRING NOT NULL,
        `price` DOUBLE NOT NULL
    ) distributed by hash(order_id) into 1 buckets
    with (
        'kafka.retention.time' = '1 d'
    );

    insert into `small-orders` select * from `examples`.`marketplace`.`orders` where price < 20;
    ```
    `distributed by hash(order_id)` and `into 1 buckets` specify that the table is backed by a Kafka topic with 1 partition, and the `order_id` field will be used as the Kafka partition key. 

???+ tip "Table with Kafka Topic metadata"
    The headers and timestamp are the only options not read-only, all are VIRTUAL. Virtual columns are by default excluded from a SELECT * similar to the system column like `$rowtime`. 

    ```sql
    ALTER TABLE <table_name> ADD (
        `headers` MAP<STRING,STRING> METADATA,
        `leader-epoch`INT METADATA VIRTUAL,
        `offset` BIGINT METADATA VIRTUAL,
        `partition` BIGINT METADATA VIRTUAL,
        `timestamp` TIMESTAMP_LTZ(3) METADATA,
        `timestamp-type` STRING METADATA VIRTUAL,
        `topic` STRING METADATA VIRTUAL
    );
    ```

    The headers can be updated within SQL statements, some values may be static or coming from the value of one of the selected field. The timestamp can also being updated and for example in most time window queries will be set to the `window_time`.

    ```sql
    CREATE TABLE clicks_per_seconds (
        events_per_second BIGINT,
        window_time TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
        )

    INSERT INTO clicks_per_seconds
    SELECT
        COUNT(*) AS events_per_second,
        window_time
    FROM TABLE(TUMBLE(TABLE clicks, DESCRIPTOR(`$rowtime`), INTERVAL '1' SECOND))
    GROUP BY window_time, window_end, window_start
    ``` 

### Applying to a Medallion Architecture

The current approach can be used for Flink pipeline processing:

| Table type | Goals | Parameters |
| --- | --- | --- |
| Raw table  non debezium format | Get the raw data from CDC or outbox pattern | cleanup.policy = 'delete', changelog.mode = 'append', value.format = 'avro-registry'...
| Raw table debezium format | Same goals | cleanup.policy = 'delete', changelog.mode = 'retract' (retract is the default for Debezium connector),  value.format = 'avro-debezium-registry'|
| Sources | Deduplicate and keep last record per key |   cleanup.policy = 'delete', changelog.mode = 'upsert' |
| Intermediates | Enrichment, transformation |    cleanup.policy = 'delete',  changelog.mode = 'upsert' |
| Sink tables: Facts, Dimensions, Views | Create star schema elements| cleanup.policy = 'compact', changelog.mode = 'retract' or 'upsert' |

### Deeper dive

* [Confluent product document - changelog ](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#changelog-mode)
* [Flink SQL Secrets: Mastering the Art of Changelog Event Out-of-Orderness](https://www.ververica.com/blog/flink-sql-secrets-mastering-the-art-of-changelog-event-out-of-orderness)
* [Resolving: Primary key differs from derived upsert key](https://docs.confluent.io/cloud/current/flink/how-to-guides/resolve-common-query-problems.html#primary-key-differs-from-derived-upsert-key)


### Confluent Cloud Flink table creation specific

[See the product documentation](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#create-table-statement-in-af-long) with some specificities, like source and sink tables are directly mapped to Kafka Topics. The `$rowtime` TIMESTAMP_LTZ(3) NOT NULL is provided as a system column.

* For each topic there is an inferred table created. The catalog is the Confluent environment and the Kafka cluster is the database. We can use the ALTER TABLE statement to evolve schemas for those inferred tables.

* A table by default is mapped to a topic with 6 partitions, and the changelog being append. Primary key leads to an implicit DISTRIBUTED BY(k), and value and key schemas are created in Schema Registry. It is possible to create table with primary key and append mode, while by default it is a upsert mode. 

    ```sql
    CREATE TABLE telemetries (
        device_id INT PRIMARY KEY NOT ENFORCED, 
        geolocation STRING, metric BIGINT,
        ts TIMESTAMP_LTZ(3) NOT NULL METADATA FROM 'timestamp')
    DISTRIBUTED INTO 4 BUCKETS
    WITH ('changelog.mode' = 'append');
    ```

The statement above also creates a metadata column for writing a Kafka message timestamp. This timestamp will not be defined in the schema registry. Compared to `$rowtime` which is declared as a `METADATA VIRTUAL` column, `ts` is selected in a `SELECT *` and is writable.

* When the primary key is specified, then it will not be part of the value schema, except if we specify (using `value.fields-include' = 'all'`) that the value contains the full table schema. The payload of k is stored twice in Kafka message:

    ```sql
    CREATE TABLE telemetries (k INT, v STRING)
    DISTRIBUTED BY (k)
    WITH ('value.fields-include' = 'all');
    ```

* If the key is a string, it may make sense to do not have a schema for the key in this case declare (the key columns are determined by the DISTRIBUTED BY clause): This does not work if the key name is not `key`.

    ```sql
    CREATE TABLE telemetries (device_id STRING, metric BIGINT)
    DISTRIBUTED BY (key)
    WITH ('key.format' = 'raw');
    ```

* To keep the record in the topic forever add this `kafka.retention.time' = '0'` as options in the WITH. The supported units are:
    ```sh
    "d", "day", "h", "hour", "m", "min", "minute", "ms", "milli", "millisecond",
    "micro", "microsecond", "ns", "nano", "nanosecond"
    ```


???+ info "CREATE TABLE in Confluent Cloud for Flink"
    The table creation creates topic and -key, -value schemas in the Schema Registry in the same environment as the compute pool in which the query is run. The `connector` is automatically set to `confluent`. 
    The non null and nullable columns are translated as the following avro fields:
    ```avro
      "fields": [
            {
            "name": "customer_id",
            "type": "string"
            },
            {
            "default": null,
            "name": "first_name",
            "type": [
                "null",
                "string"
            ]
            }
      ]
    ```

    DATE as:

    ```avro
    {
      "default": null,
      "name": "registration_date",
      "type": [
        "null",
        {
          "logicalType": "local-timestamp-millis",
          "type": "long"
        }
      ]
    }
    ```


## Analyzing Table

### Understand the type of attribute or get the table structure with metadata

```sql
show create table 'tablename';
-- for a specific attribute
select typeof(column_name) from table_name limit 1;
```

Flink SQL planner performs type checking. Assessing the type of inferred table is helpful, specially around timestamp. See [Data type mapping documentation.](https://docs.confluent.io/cloud/current/flink/reference/serialization.html)
