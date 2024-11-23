# Flink SQL and Table API

???- Info "Updates"
    Created 10/24
    Revised 11/23/24


This chapter offers a compilation of best practices for implementing Flink SQL, applicable to both local open-source setups and environments utilizing Confluent Platform for Flink or Confluent Cloud for Flink.

## Getting Started with a SQL client

Use one of the following approaches:

* Use SQL client in container (docker or kubernetes) to run against local Flink cluster. (See [deployment/custom-flink-image](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/custom-flink-image) folder to build a custom image using the dockerfile with the sql-client service).
* Use Confluent Cloud Flink console to write long running statements.
* Use confluent cli connected to a compute pool on **Confluent Cloud**, using an environment and compute-pool already created. (To create a new environment using Terraform use [this note](terraform.md))

???- info "SQL client with confluent cli"
    [See quick start note](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-shell.html) which is summarized as:

    * Connect to Confluent Cloud with CLI, then get environment and compute pool

    ```sh
    confluent login --save
    ```

    * Start local SQL client - using the `aws-west` environment.

    ```sh
    export ENV_ID=$(confluent environment list -o json | jq -r '.[] | select(.name == "aws-west") | .id')
    export COMPUTE_POOL_ID=$(confluent flink compute-pool list -o json | jq -r '.[0].id')
    confluent flink shell --compute-pool $COMPUTE_POOL_ID --environment $ENV_ID
    ```

    * Write SQL statements

    * Some interesting commands:

    ```sql
    USE CATALOG `examples`;
    USE `marketplace`;
    SHOW TABLES;
    SHOW JOBS;
    DESCRIBE tablename;
    ```

* Write SQL statements and test them with Java SQL runner. The Class is in [https://github.com/jbcodeforce/flink-studies/tree/master/flink-java/sql-runner](https://github.com/jbcodeforce/flink-studies/tree/master/flink-java/sql-runner) folder.

## DDL statements

Data Definition Language (DDL) are statements to define metadata in Flink SQL by creating, changing, or deleting tables.

A table registered with the CREATE TABLE statement can be used as both table source and table sink.

Flink can generate updates for a given key. There are [different modes](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#changelog-mode) for persistence: append, retract or upsert. 

* **append** means that every row can be treated as an independent fact.
* **retract** means that the combination of +X and -X are related and must be partitioned together.
* **upsert** means that all rows with same primary key are related and must be partitioned together

The `change.log` property is set up using the `WITH ('changelog.mode' = 'upsert')`.

Changelog in Flink SQL is used to record the data changes in order to achieve incremental data processing.
Some operations in Flink such as group aggregation and deduplication can produce update events.

[See the concept of changelog and dynamic tables in Confluent documentation.](https://docs.confluent.io/cloud/current/flink/concepts/dynamic-tables.html)

### Table creation

???- info "Primary key considerations"
    * primary key can have one or more columns, all of them are not null
    * the keys can only be `NOT ENFORCED`
    * The PRIMARY KEY constraint partitions the table implicitly by the key column
    * The primary key is becoming the kafka key implicitly.

???- info "Create a table with csv file as persistence - Flink OSS"
    We need to use file system connector.

    ```sal
    create table user (
        'user_id VARCHAR(250),
        'name' VARCHAR(50)
    ) partitioned by ('used-id')
    WITH (
        'format' = 'json', -- other format are: csv, parquet
        'connector' = 'filesystem',
        'path' = '/tmp/users'
    );
    ```


???- question "How to consume from a Kafka topic to a SQL table?"
    On Confluent Cloud for flink, there are already tables created for each topic. For local Flink we need to create table with column definitions that maps to attributes of the record. The `From` right operand proposes the list of topic/table for the catalog and database selected. For Flink OSS or Confluent Platform for Flink the `WITH` statement helps to specify the source topic.

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

    For Avro and schema registry with open source Flink. See the tools [extract_sql_from_avro.py]() to query Confluent Schema Registry running locally and build the matching SQL to create a table connected to the topic using this schema.

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

 

???- question "How to load data from a csv file using filesystem connector using SQL (Local execution only)"
    Enter the following statement in a SQL client session:

    ```sql
    SET execution.runtime-mode=BATCH;
    ```
    Create a table from the content of the file

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

    [See complete example in the readme](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/00-basic-sql)


???- question "How to add a field in a table?"
    [Use ALTER TABLE](https://docs.confluent.io/cloud/current/flink/reference/statements/alter-table.html)
    
    ```sql
    alter table flight_schedules add(dt string);
    ```

???- question "Create a table as another one by inserting all records with similar schema - select (CTAS create table as select)"
    [CREATE TABLE AS SELECT](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#create-table-as-select-ctas) is used to create table and insert values in the same statement.
    
    By using a primary key:

    ```sql
    create table shoe_customer_keyed(
        primary key(id) not enforced
    ) distributed by(id) into 1 buckets
    as select id, first_name, last_name, email from shoe_customers;
    ```

??? - question "How to generate data using [Flink Faker](https://github.com/knaufk/flink-faker)?"
    Create at table with records generated with `faker` connector using the [DataFaker expressions.](https://github.com/datafaker-net/datafaker). 
    Valid only on OSS Flink or on-premises.

    ```sql
    CREATE TABLE `bounded_pageviews` (
      `url` STRING,
      `user_id` STRING,
      `browser` STRING,
      `ts` TIMESTAMP(3)
    )
    WITH (
      'connector' = 'faker',
      'number-of-rows' = '500',
      'rows-per-second' = '100',
      'fields.url.expression' = '/#{GreekPhilosopher.name}.html',
      'fields.user_id.expression' = '#{numerify ''user_##''}',
      'fields.browser.expression' = '#{Options.option ''chrome'', ''firefox'', ''safari'')}',
      'fields.ts.expression' =  '#{date.past ''5'',''1'',''SECONDS''}'
    );
    ```
    This will only work in customized flink client with the jar from flink faker.

???- info "Generate data with dataGen for Flink OSS"
    [Use DataGen to do in-memory data generation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/datagen/)

???- question "How to generate test data to Confluent Cloud Flink?"
    Use Kafka Connector with DataGen. Those connector exists with a lot of different pre-defined model. Also it is possible to define custom Avro schema and then use predicates to generate data. There is a [Produce sample data quick start tutorial from the Confluent Cloud home page](https://docs.confluent.io/cloud/current/connectors/cc-datagen-source.html). See also [this readme](2933https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql/01-confluent-kafka-local-flink).

???- question "How to transfer the source timestamp to another table"
    As $rowtime is the timestamp of the record in Kafka, it may be interesting to keep the source timestamp to the downstream topic.

    ```sql
    create table `new_table` (
          `order_id` STRING NOT NULL,
          ...
          `event_time` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp')
    distributed.... 
    ```

    Then the move data will look like:
    
    ```sql
    insert into `some_clicks`
    select
        order_id, 
        user_id,

        $rowtime as event_time
    from  `src_table`
    ```

???- question "Dealing with late event"
    Any streams mapped to a table have records arriving more-or-less in order, according to the $rowtime, and the watermarks let the Flink SQL runtime know how much buffering of the incoming stream is needed to iron out any out-of-order-ness before emitting the sorted output stream.

    We need to  specify the watermark strategy as for example within 30 second of the event time:

    ```sql
    create table new_table (
        ....
        `event_time` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp',
     watermark for `event_time` as `event_time` - INTERVAL '30' SECOND
    );
    ```


???- question "Create a table with topic as persistence"
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
    `distributed by hash(order_id)` and `into 1 buckets` specify that the table is backed by a Kafka topic with 1 partitions, and the order_id field will be used as the partition key. 

#### Confluent Flink table creation

[See the product documentation](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#create-table-statement-in-af-long) with some specifities, like source and sink tables are mapped to Kafka Topics. The `$rowtime` TIMESTAMP_LTZ(3) NOT NULL is provided as a system column.
For each topic there is an inferred table created. The catalog is the Confluent environment and the Kafka cluster is the databsase. We can use the ALTER TABLE statement to evolve schemas for those inferred tables.

## DML statements

Data modification language, is used to define statements  which modify the data and don’t change metadata.

### Common patterns

???- question "How to filter out records?"

    using the [WHERE clause]()

    ```sql
    select * from flight_events where status = 'cancelled';
    ```

    Count the number of events related to a cancelled flight (need to use one of the selected field as grouping key):

    ```sql
    select fight_id, count(*) as cancelled_fl from FlightEvents where status = 'cancelled' group by flight_id;
    ```

    Recall that this results produces a dynamic table.

???- questiom "How to transform a field representing epoch to a timestamp?"
    ```sql
     TO_TIMESTAMP(FROM_UNIXTIME(click_ts_epoch)) as click_ts
    ```

???- question "How to change a date string to a timestamp?"
    ```sql
    TO_TIMESTAMP('2024-11-20 12:34:568Z'),
    ```
    See all the [date and time functions](https://docs.confluent.io/cloud/current/flink/reference/functions/datetime-functions.html).

???- question "How to compare a date field with current system time?"
    ```sql
    WHEN TIMESTAMPDIFF(day, event.event_launch_date, now()) > 120 THEN ...
    ```
    The table used as target to this processing, if new records are added to it, then needs to be append log, as if it is upsert then the now() time is not determenistic for each row to process.

???- question "How to mask a field?"
    Create a new table from the existing one, and then use REGEXP_REPLACE to mask an existing attribute

    ```sql
    create table users_msk like users;
    INSERT INTO users_msk SELECT ..., REGEXP_REPLACE(credit_card,'(\w)','*') as credit_card FROM users;
    ```

???- question "What are the different SQL execution modes?"

    Using previous table it is possible to count the elements in the table using:

    ```sql
    select count(*) AS `count` from pageviews;
    ```

    and we get different behavior depending of the execution mode:

    ```sql
    set 'execution.runtime-mode' = 'batch';
    # default one
    set 'execution.runtime-mode' = 'streaming';

    set 'sql-client.execution.result-mode' = 'table';
    ```

    In changelog mode, the SQL Client doesn't just update the count in place, but instead displays each message in the stream of updates it's receiving from the Flink SQL runtime.
    
    ```sql
    set 'sql-client.execution.result-mode' = 'changelog';
    ```

    ![](./images/changelog-exec-mode.png)


???- question "When and how to use custom watermark?"
    Developer should use their own [watermark strategy](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#watermark-clause) when there are not a lot of records per topic/partition, there is a need for a large watermark delay, and need to use another timestamp. 

???- info "How to join two tables on a key within a time window and store results in target table?"
    ```sql
    create table Transactions (ts TIMESTAMP(3), tid BIGINT, amount INT);
    create table Payments (ts TIMESTAMP(3), tid BIGINT, type STRING);
    create table Matched (tid BIGINT, amount INT, type STRING);
    insert into Matched 
        select T.tid, T.amount, P.type
        from Transactions T join Payments P ON T.tid = P.tid 
        where P.ts between T.ts and T.ts + interval '10' minutes;
    ```
    
???- question "Deduplication example"

    ```sql
    SELECT ip_address, url, TO_TIMESTAMP(FROM_UNIXTIME(click_ts_raw)) as click_timestamp
    FROM (
        SELECT *,
        ROW_NUMBER() OVER ( PARTITION BY ip_address ORDER BY TO_TIMESTAMP(FROM_UNIXTIME(click_ts_raw)) ) as rownum FROM clicks
        )
    WHERE rownum = 1;
    ```

    [See this example](https://docs.confluent.io/cloud/current/flink/how-to-guides/deduplicate-rows.html#flink-sql-deduplicate-topic-action)

### Windowing / Table Value Functions

[Windowing Table-Valued Functions](https://docs.confluent.io/cloud/current/flink/reference/queries/window-tvf.html) groups the Tumble, Hop, Cumulate, and Session Windows. Windows split the stream into “buckets” of finite size, over which we can implement logic. The return value adds three additional columns named “window_start”, “window_end”, “window_time” to indicate the assigned window.

* The TUMBLE function assigns each element to a window of specified window size. Tumbling windows have a fixed size and do not overlap.

???- question "Count the number of different product type per 10 minutes (TUMBLE window)"
    [Aggregate a Stream in a Tumbling Window documentation.](https://docs.confluent.io/cloud/current/flink/how-to-guides/aggregate-tumbling-window.html). 
    The following query counts the number of different product types arriving from the event stream by interval of 10 minutes.

    ```sql
    SELECT window_start, product_type, count(product_type) as num_ptype
        FROM TABLE(
            TUMBLE(
                TABLE events,
                DESCRIPTOR(`$rowtime`),
                INTERVAL '10' MINUTES
            )
        )
        GROUP BY window_start, window_end, ;
    ```
    *DESCRIPTOR* indicates which time attributes column should be mapped to tumbling windows (here the kafka record ingestion timestamp). 
    
    When the internal time has expired the results will be published. This puts an upper bound on how much state Flink needs to keep to handle a query, which in this case is related to the number of different product type. 



???- question "Aggregation over a window"
    Windows over approach is to end with the current row, and stretches backwards through the history of the stream for a specific interval, either measured in time, or by some number of rows.
    For example counting the umber of flight_schedule events of the same key over the last 100 events:

    ```sql
    select
        flight_id,
        evt_type,
        count(evt_type) OVER w as number_evt,
    from flight_events
    window w as( partition by flight_id order by $rowtime rows between 100 preceding and current row);
    ```

    The results are updated for every input row. The partition is by flight_id. Order by $rowtime is necessary.

???- question "Find the number of elements in x minutes intervals advanced by 5 minutes? (HOP)"
    [Confluent documentation on window integration.](https://docs.confluent.io/cloud/current/flink/reference/queries/window-tvf.html). For **HOP** wuindow, there is the slide parameter to control how frequently a hopping window is started:

    ```sql
        SELECT
            window_start, window_end,
            COUNT(DISTINCT order_id) AS num_orders
        FROM TABLE(
            HOP(TABLE shoe_orders, DESCRIPTOR(`$rowtime`), INTERVAL '5' MINUTES, INTERVAL '10' MINUTES))
        GROUP BY window_start, window_end;
    ```

???- question "How to compute the accumulate price over time in a day (CUMULATE)"
    Needs to use the cumulate window, which adds up records to the window until max size, but emits results at each window steps. 
    The is image summarizes well the behavior:
    ![](https://docs.confluent.io/cloud/current/_images/flink-cumulating-windows.png)

    ```sql
    SELECT window_start, window_end, SUM(price) as `sum`
        FROM TABLE(
            CUMULATE(TABLE `examples`.`marketplace`.`orders`, DESCRIPTOR($rowtime), INTERVAL '30' SECONDES, INTERVAL '3' MINUTES))
        GROUP BY window_start, window_end;
    ```

### Row pattern recognition

???- question "Find the longest period of time for which the average price of a stock did not go below a value"
    Create a Datagen to publish StockTicker to a Kafka topic.
    [See product documentation on CEP pattern with SQL](https://nightlies.apache.org/flink/flink-docs-release-1.15/docs/dev/table/sql/queries/match_recognize/)
    
    ```sql
    create table StockTicker(symbol string, price int tax int) with ('connector' = 'kafka',...)
    SELECT * From StockTicker 
    MATCH_RECOGNIZE ( 
        partition by symbol 
        order by rowtime
        measures
            FIRST(A.rowtime) as start_tstamp,
            LAST(A.rowtime) as last_tstamp,
            AVG(A.price) as avgPrice
        ONE ROW PER MATCH
        AFTER MATCH SKIP PAST LAST ROW
        PATTERN (A+ B)
        DEFINE
            A as AVG(A.price) < 15
    );
    ```

    MATCH_RECOGNIZE helps to logically partition and order the data that is used with the PARTITION BY and ORDER BY clauses, then defines patterns of rows to seek using the PATTERN clause.
    The logical components of the row pattern variables are specified in the DEFINE clause.
    B is defined implicitly as not being A.

## Confluent Cloud Specific

[See Flink Confluent Cloud queries documentation.](https://docs.confluent.io/cloud/current/flink/reference/queries/overview.html)

Each topic is automatically mapped to a table with some metadata fields added, like the watermark in the form of `$rowtime` field, which is mapped to the Kafka record timestamp. To see it, run `describe extended table_name;` With watermarking. arriving event records will be ingested roughly in order with  respect to the `$rowtime` time attribute field.

???- question "Mapping from Kafka record timestamp and table $rowtime"
    The Kafka record timestamp is automatically mapped to the `$rowtime` attribute, which is a read only field. Using this field we can order the record by arrival time:

    ```sql
    select 'flight_id', 'aircraft_id', 'status', $rowtime
    from Aircrafts
    order by $rowtime;
    ```


???- question "How to run Confluent Cloud for Flink?"
    See [the note](../techno/ccloud-flink.md), but can be summarized as: 1/ create a stream processing compute pool in the same environment and region as the Kafka cluster, 2/ use Console or CLI (flink shell) to interact with topics.

    ![](../techno/diagrams/ccloud-flink.drawio.png)

    ```sh
    confluent flink quickstart --name my-flink-sql --max-cfu 10 --region us-west-2 --cloud aws
    ```

???- question "Running Confluent Cloud Kafka with local Flink"
    The goal is to demonstrate how to get a cluster created in an existing Confluent Cloud environment and then send message via FlinkFaker using local table to Kafka topic:
    
    ![](./diagrams/flaker-to-kafka.drawio.png)

    The [scripts and readme](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql/01-confluent-kafka-local-flink) .

???- question "Supported connector for Flink SQL and Confluent Cloud"
    See the [product documentation at this link]().

???- question "create a long running SQL with cli"
    Get or create a service account.
    ```sh
    confluent iam service-account create my-service-account --description "new description"
    confluent iam service-account list
    confluent iam service-account describe <id_of_the_sa>
    ```

    ```sh
    confluent flink statement create my-statement --sql "SELECT * FROM my-topic;" --compute-pool <compute_pool_id> --service-account sa-123456 --database my-cluster
    ```

???- question "Assess the current flink statement running in Confluent Cloud"
    To assess which jobs are still running, which jobs failed, and which stopped, we can use the user interface, go to the Flink console > . Or the `confluent` CLI:

    ```sh
    confluent environment list
    confluent flink compute-pool list
    confluent flink statement list --cloud aws --region us-west-2 --environment <your env-id> --compute-pool <your pool id>
    ```

