# Flink SQL Basic Examples

#### Versions
    Created from Flink Study 2021
    Updated 1/2025 from Confluent Flink studies
    Updated 12/2025 Getting started by using Flink SQL client - Add deduplicate for Apache Flink OSS
    Update 2/2026: Clean readme and automate demonstration. Add REST client in python to management statement and rund demonstration.

This folder includes some basic SQL examples to be used with one of the following environments:

* [Local Apache Flink cluster with SQL Client](#apache-flink-oss)
* [Confluent Cloud Deployment and validation](#confluent-cloud-flink)
* [Local Confluent Platform for Flink on Kubernetes](#confluent-platform-for-flink-on-kubernetes)

What is demonstrated:
* Table creation, loading from CSV file and writing results to CSV file, when running with Apache Flink locally
* Deduplication within CTE, grouping and aggregates
* Snapshot Query
* Running Confluent Cloud deployment using a REST client in python.

## First Use Case

The common example to run in all environment is to [process employee data from csv](#employees-demo) to count the  number of employees per department. This is basic but let see how one problem can be executed in different Flink flavors.

This demonstration is based on the SQL getting started [Flink 2.1 documentation](https://nightlies.apache.org/flink/flink-docs-release-2.1/docs/dev/table/sql/gettingstarted/).

The [data/employee.csv](https://github.com/jbcodeforce/flink-studies/blob/master/code/flink-sql/00-basic-sql/data/employes.csv) has 15 records.

* The following job is a batch processing and uses a DDL to create a table matching the column of a employee csv file. It used Flink file system source connector:

```sql
CREATE TABLE employees (
    emp_id INT,
    name VARCHAR,
    dept_id INT
) WITH (
    'connector' = 'filesystem',
    'path' = './data/employees.csv',
    'format' = 'csv'
);
```

* Using the SQL client, we can select some data from this table: 

```sql
SELECT * from employees WHERE dept_id = 102;
```

**Potential Error**:
* "The jobGraphFileName field must not be omitted or be null." This could be done because of running different version between client and cluster.


### Deduplication

The csv data has two employee_id = 10. It is possible to apply the standard Top-1 pattern to remove the last record:
```sql
select *  FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY emp_id 
            ORDER BY emp_id DESC
        ) AS row_num
    FROM employees
) WHERE row_num = 1;
```

Element 10 is present only one time.

### Aggregation

Count the  number of employees per department, with this query:

```sql
select dept_id, count(*) as employees_dept from employees group by dept_id;
```
The expected results are:

```sh
dept_id       employees_dept
    104            1
    103            4
    102            6
    101            5
```

The results are wrong, so we need to combine deduplication and aggregation using CTE. 

As we work from file content, which is bounded, we need to specify the runtime mode to be batch:

```sql
SET 'execution.runtime-mode' = 'batch';
```

To get the analytic results to external applications, we need to define a sink table, saved to file system for example:

```sql
CREATE TABLE department_counts (
    dept_id INT,
    emp_count BIGINT NOT NULL
) WITH ( 
    'connector' = 'filesystem',
    'path' = './data/dept_count',
    'format' = 'csv'
);
```

See [first_use_case.sql](./oss-flink/first_use_case.sql) for the end to end solution.

### Snapshot Query

On Confluent Cloud, it is possible to run a query with bounded stream, bounded by the current time. The CC Flink demonstration illustrates this query.

```sql
set "sql.snapshot.mode": "now";
SELECT * FROM employee_count;
```

See [the example from Confluent tutorials](https://docs.confluent.io/cloud/current/flink/how-to-guides/run-snapshot-query.html). 

## Apache Flink OSS

* [See the deployment readme](../../../deployment/product-tar/README.md) in this repository to get last Apache Flink OSS image.
* Once Flink cluster started, run the Flink SQL Client:
    ```sh
    # under deployment/product-tar
    export FLINK_HOME=$(pwd)/flink-2.1.1
    export PATH=$PATH:$FLINK_HOME/bin
    # Start the cluster
    $FLINK_HOME/bin/start-cluster.sh
    # Then sql client in interactive mode
    $FLINK_HOME/bin/sql-client.sh embedded -i ./oss-flink/init_session.sql
    ```

    The above commands are in one shell: `./start_flink_oss.sh`

* Once connected set default catalog and db.

```sh
show catalogs;
use catalog j9r_catalog;
show databases;
use j9r_db
show tables;
show functions;
```

Should get an empty set. 

* For all interactive demonstration, copy past the previous SQL statements
* Exit the shell

* Run the employee count per department demonstration in one file, using a session cluster:
  ```sh
  $FLINK_HOME/bin/sql-client.sh -i ./oss-flink/init_session.sql -f ./oss-flink/first_use_case.sql
  ```

  The results are in tableau format with the log operation, the results are correct and visible in the `./data/dept_count` folder, as the SQL has a sink connector to filesystem.

* If needed terminate the cluster
```
$FLINK_HOME/bin/stop-cluster.sh 
```

## Confluent Cloud Flink

To deploy the same SQL scripts to Confluent Cloud for Flink we need to have some environment defined. The terraform in [deployment/cc-terraform](../../../deployment/cc-terraform/) can be used to prepare such environment.

Deploying SQL queries can be done using `confluent cli`. 

* The demonstration is controlled by a python code:
  ```sh
  cd ..
  uv run  python 00-basic-sql/cc_flink_employees_demo.py
  ```

* In case you need to rerun the snapshot query do:
  ```sh
  uv run python 00-basic-sql/cc_flink_employees_demo.py --snapshot-query-only
  ```
  
  See [the example from Confluent tutorials](https://docs.confluent.io/cloud/current/flink/how-to-guides/run-snapshot-query.html). 


* To clean up
  ```sh
  uv run  python 00-basic-sql/cc_flink_employees_demo.py --delete-only
  ```

## Confluent Platform for Flink on Kubernetes

1. Start Kubernetes with [Orbstack](../../../deployment/k8s).
    ```sh
    make start_orbstack
    ```

1. Start SQL client
  ```sh
  kubectl get pods
  kubectl exec -ti <flink-pod> -- bash
  # then in the container shell
  sql-client.sh
  ```

To Be Continued

--- 
## Second use case

Use Faker to generate synthetic data.

--- ! this does not work with Flink 2.1.1

This example  is based on [Batch and Stream Processing with Flink SQL (Confluent Exercise)](https://developer.confluent.io/courses/apache-flink/stream-processing-exercise/)

See [The flink-faker github.](https://github.com/knaufk/flink-faker?tab=readme-ov-file) and install the jar in the lib of the Apache Flink installation.

Create a fixed-length (bounded) table with 500 rows of data generated by the faker table source. [Flink-faker](https://github.com/knaufk/flink-faker) tool is a convenient and powerful mock data generator designed to be used with Flink SQL.

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

*Remarks: Creating this table does not triggers the execution of the connector.* 

```sql
set 'sql-client.execution.result-mode' = 'changelog';

select count(*) AS `count` from bounded_pageviews;
```

## Confluent Cloud Flink

The `cc-flink/ddl.customers.sql` creates a simple customers table. Running this query inside the Confluent Cloud Console -> Flink -> Workspace. This will create the `customers` topic, the -key and -value schemas.

Use the terraform to deploy it. 

**Prerequisites:** Environment, Kafka cluster, Flink compute pool, and a service account with an API key scoped to the Flink region must already exist. Set all IDs and credentials in `terraform.tfvars`.

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values.
2. From this directory: `terraform init`, `terraform plan`, `terraform apply`.

### Deduplication example

The insert to customers includes two records for CUST_01, with different timestamp and street address to help validating the last record is kept. The `registration_date` is the timestamp to sort on. It may be a best practice to keep the key as part of the column values by using the following configuration: `'value.fields-include' = 'all'`

The `cc-flink/ddl.customers.sql` is an `append` table so doing a `select * from customers` in the CC Workspace will returns all records of CUST_01. Changing back the changelog mode to `upsert`, with: 

```sql
alter table `customers` SET ('changelog.mode' = 'upsert')
```
Will remove duplicate records in the table.

For append mode source table, the `dml.dedup_customers.sql` illustrates the deduplication approach using ROW_NUMBER() function.
As for eack key, there may be update and delete changes done, the changelog has to be `upsert`

```sql
create table customers_dedup (
  primary key(customer_id) not enforced
)
DISTRIBUTED BY HASH(customer_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'delete',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
) as select 
  --- omitted
from (
  select *,
  ROW_NUMBER() OVER ( PARTITION BY customer_id ORDER BY registration_date DESC) as row_num
  from customers
) where row_num = 1;
```

A select * on this dedup table, gives the expected results. In the kafka topic at offset 0 the first CUST_01 record will be the old one, while around offset 8 the new CUST_01 is present: this is normal.

### Tombstone creation

From the dedupled topic, we can add another processing to get Premium customers

```sh
create table `customers_filtered` (
  primary key(customer_id) not enforced 
) 
as select * from `customers_dedup` where customer_segment = 'Premium'
```

Last we want to modify CUST001 again by changing the customer_segment to Standard, but to make it working and pass the dedup, we also need to change the registration_date to be later than the creation of the first CUST001.
```sql
insert into `customers` values ('CUST001', 'John', 'Smith', 'john.smith@email.com', '555-0101', DATE '1985-03-15', 'M', TIMESTAMP '2024-01-25 10:23:45.123', 'Standard', 'Email', '123 3nd Oak Street', 'New York', 'NY', '10001', 'USA')
```

If the `select * from customers_filtered` is still running we can see the CUST001 is no more in the Premium list, and in the `customers_filtered` topic a tombstone record is present:
![](./images/tombstone_cust.png)


* See also the [json transformation demo](../../../e2e-demos/json-transformation/README.md) as a basic ARRAY, ROW to JSON Object transformation, runnable in CC Flink or CP Flink.

### Snapshot Query


The most important thing is to set the mode and read from append model only table.

```sql
SET 'sql.snapshot.mode' = 'now';
select * from `customers`
-- select * from dedup_customers   WILL NOT work
```

[Next will be Kafka integration running locally or on Confluent Cloud](../01-confluent-kafka-local-flink/README.md)
