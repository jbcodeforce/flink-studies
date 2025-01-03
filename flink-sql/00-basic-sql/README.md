# Flink SQL some basic examples

#### Version
    Created from Flink Study 2021 
    Updated 10/2024 from Confluent Flink studies

Start one Flink **Job manager** and one **Task manager** container, using the docker compose in deployment-local folder of this project. The docker engine mounts this project folder in `/home`, so content of the data will be in `/home/flink-sql/data` 

As an alternate, it is easy to install Flink locally and start the cluster and SQL client. [See this note](https://jbcodeforce.github.io/flink-studies/coding/getting-started/#install-locally).

## Pre-requisite

* Build custom flink image using dockerfile under `deployment/custom-flink-image`
* Start docker compose under `deployment/docker`.
* Access Flink dashboard at [localhost:8081](http://localhost:8081/). See [this tutorial for UI introduction](https://developer.confluent.io/courses/apache-flink/web-ui-exercise/).

## First demo 

This demonstration is based on the SQL getting started [Flink documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sql/gettingstarted/).

The [data/employee.csv](https://github.com/jbcodeforce/flink-studies/blob/master/flink-sql/00-basic-sql/data/employes.csv) has 15 records.

Connect to the SQL client container via:

```sh
docker exec -it sql-client bash
# then in the container shell
sql-client.sh
# Validate some basic query
show tables;
```

The following job is a batch processing and uses a DDL to create a table matching the column of a employee csv file. 

```sql
SET execution.runtime-mode=BATCH;

CREATE TABLE employes (
    emp_id INT,
    name VARCHAR,
    dept_id INT
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql/data/employes.csv',
    'format' = 'csv'
);
```

Using the SQL client, we can select some data from this table: 

```sql
SELECT * from employee_info WHERE dept_id = 101;
```

Or count the employees per department, with this static query:

```sql
select dept_id, count(*) from employee_info group by dept_id;
```

When moving to data streaming, aggregations need to store aggregated results continuously during the execution of the query. Therefore the query needs to maintain the most up to date count for each department to output timely results as new rows are processed. This is a **Stateful** query.  Flink’s advanced fault-tolerance mechanism maintains internal state and consistency, so queries always return the correct result, even in the face of hardware failure.

To get the analytic results to external applications, we need to define sinks by adding a sink table like below:

```sql
CREATE TABLE department_counts (
    dept_id INT,
    emp_count BIGINT NOT NULL
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql/00-basic-sql/',
    'format' = 'csv'
);
```

```sql
SET 'sql-client.execution.result-mode' = 'table';
```

```sql
INSERT INTO department_counts
SELECT 
   dept_id,
   COUNT(*) as emp_count 
FROM employee_info
GROUP BY dept_id;
```

* Terminate the SQL client session

```sql
exit();
```


## Example based on [Batch and Stream Processing with Flink SQL (Confluent Exercise)](https://developer.confluent.io/courses/apache-flink/stream-processing-exercise/)

Create a fixed-length (bounded) table with 500 rows of data generated by the faker table source. [flink-faker](https://github.com/knaufk/flink-faker) is a convenient and powerful mock data generator designed to be used with Flink SQL.

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

```sql
set 'sql-client.execution.result-mode' = 'changelog';


select count(*) AS `count` from bounded_pageviews;
```


[Next will be Kafka integration running locally or on Confluent Cloud](../01-confluent-kafka-local-flink/README.md)
