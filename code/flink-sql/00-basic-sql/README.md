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
* Process employees data to aggregate by department id.
* Table creation, loading from CSV file and writing results to CSV file
* Deduplication within CTE, grouping and aggregates


# Employees Aggregation

The goal is to process employee data and  to count the  number of employees per department. This is basic but let see how one problem can be executed in different Flink flavors.

This demonstration is based on the SQL getting started from the [Apache Flink 2.1 documentation](https://nightlies.apache.org/flink/flink-docs-release-2.1/docs/dev/table/sql/gettingstarted/). The [data/employee.csv](https://github.com/jbcodeforce/flink-studies/blob/master/code/flink-sql/00-basic-sql/data/employes.csv) has 15 records.


## Apache Flink OSS

* The following job is a batch processing and uses a DDL to create a table matching the columns of a employee csv file. It uses Apache Flink file system source connector:


* [See the deployment readme](../../../deployment/product-tar/README.md) in this repository to get last Apache Flink OSS image and then start it.
* Once Flink cluster is started, run the Apache Flink SQL Client:
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

* Create the employee table:
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

* We can select some data from this table: 

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

See [./oss-flink/first_use_case.sql](./oss-flink/first_use_case.sql) for the end to end solution.

* Exit the shell

* You can also run the employee count per department demonstration in one file, using a session cluster:
  ```sh
  $FLINK_HOME/bin/sql-client.sh -i ./oss-flink/init_session.sql -f ./oss-flink/first_use_case.sql
  ```

  The results are in tableau format with the log operation, the results are correct and visible in the `./data/dept_count` folder, as the SQL has a sink connector to filesystem.

* When needed, terminate the cluster
```
$FLINK_HOME/bin/stop-cluster.sh 
```

## Confluent Cloud Flink

To deploy the same SQL scripts to Confluent Cloud for Flink we need to have some environment defined. The terraform in [deployment/cc-terraform](../../../deployment/cc-terraform/) can be used to prepare such environment, get a kafka cluster, schema registry and two Flink compute pools.

Deploying SQL queries can be done using `confluent cli`. 

* The demonstration is controlled by one python code:
  ```sh
  cd ..
  uv run  python 00-basic-sql/cc_flink_employees_demo.py
  ```

* On Confluent Cloud, it is possible to run a query with bounded stream, bounded by the current time. The CC Flink demonstration illustrates this query.
  ```sql
  set "sql.snapshot.mode": "now";
  SELECT * FROM employee_count;
  ```

* In case you need to rerun the snapshot query do:
  ```sh
  uv run python 00-basic-sql/cc_flink_employees_demo.py --snapshot-query-only
  ```
  
  See [the snapshot query example from Confluent tutorials](https://docs.confluent.io/cloud/current/flink/how-to-guides/run-snapshot-query.html). 


* To clean up
  ```sh
  uv run  python 00-basic-sql/cc_flink_employees_demo.py --delete-only
  ```

## Confluent Platform for Flink on Kubernetes

Here we have two approaches: 
* one using kafka topics as sources and sink of the SQL statmeent. This is the current approach for CP-Flink with SQL catalog and database being Kafka and tables being topics. This means topics and schemas need to be created with Yaml files
* Package the SQL as done with Apache Flink and deploy using FKO


One Python script deploys the same employee SQLs to Confluent Platform Flink (CMF) and validates execution end-to-end. 
The SQL ddls are modified to use filesystems connectors and as CP Flink (2/2026) does not support CTAS yet.

**Prerequisites**

1. Start Kubernetes (e.g. [Orbstack](../../../deployment/k8s)) and deploy CP Flink (see [deployment/k8s/cmf](../../../deployment/k8s/cmf) and [k8s-deploy](../../../docs/coding/k8s-deploy)).
2. Ensure pods are Running in the `confluent` namespace:
   ```sh
   kubectl get pods -n confluent
   ```
   Expected: `confluent-manager-for-apache-flink`, `kafka-*`, `schemaregistry-*` (and optionally `flink-kubernetes-operator`, `controlcenter-ng-*`).
3. CMF REST API must be reachable. Either run port-forward in another terminal:
   ```sh
   cd deployment/k8s/cmf && make port_forward_cmf
   ```
   Or let the script start it (unless `--no-port-forward` is set).
4. Create Flink environment, Kafka catalog, and compute pool (one-time):
   ```sh
   cd deployment/k8s/cmf
   make deploy
   make create_flink_env create_kafka_catalog create_compute_pool
   ```

**Config (optional env)**

- `CMF_BASE_URL` (default `http://localhost:8084`)
- `CMF_ENV_NAME` (default `dev-env`), `CMF_COMPUTE_POOL_NAME` (default `pool1`)
- `CMF_CATALOG_NAME` (default `dev-catalog`), `CMF_DATABASE_NAME` (default `kafka-db`)
- `KUBECTL_NAMESPACE` (default `confluent`)

**Run full validation**

From repo root or `code/flink-sql`:

```sh
uv run python 00-basic-sql/cp_flink_employees_demo.py
```

The script checks pods, ensures CMF is reachable, verifies environment and catalog exist, deploys DDL (employees table), inserts data, runs the CTAS (employee_count), runs a snapshot query, and asserts department counts (101->5, 102->6, 103->4, 104->1).

**Options**

- `--skip-kubectl`: Skip pod check (e.g. when port-forward is from another machine).
- `--no-port-forward`: Do not start port-forward; fail if CMF is unreachable.
- `--delete-only`: Drop tables and delete statements only.
- `--ddl-only`: Deploy only the employees DDL.
- `--validate-only`: Run snapshot query and assert counts (tables must already exist).

**Cleanup**

```sh
uv run python 00-basic-sql/cp_flink_employees_demo.py --delete-only
```

**Send employee data to the employees Kafka topic**

After port-forwarding Kafka, from `code/flink-sql` or `00-basic-sql`:

```sh
uv run python 00-basic-sql/cp-flink/send_employees_to_kafka.py
```

For the kraft cluster ([deployment/k8s/cfk/kraft-cluster.yaml](../../../deployment/k8s/cfk/kraft-cluster.yaml)) with listener on 9092, forward the same port:

```sh
kubectl port-forward svc/kafka 9092:9092 -n confluent
```

The script uses `KAFKA_BOOTSTRAP_SERVERS` (default `localhost:9092`). If port-forward fails with "Connection refused", the service port may not match the pod listener; run `kubectl get svc kafka -n confluent` and forward to the pod port (e.g. if the pod listens on 9071, use `9092:9071` and keep bootstrap `localhost:9092`). Records are read from `00-basic-sql/data/employees.csv` and produced as JSON to the `employees` topic.

**Run DML (e.g. employee_count) in "SQL client" against CP Flink in Kubernetes**

CP Flink in Kubernetes is driven by the CMF REST API. There is no bundled Flink `sql-client.sh` that connects to CMF. To run [cp-flink/dml.employee_count.sql](cp-flink/dml.employee_count.sql) (or any SQL) you can:

1. **Use the demo script (recommended)**  
   After Kafka topics/schemas exist and the `employees` table is available (Kafka catalog + topic/schema), run the full flow; it submits the DML via the REST API and waits for the statement to be RUNNING or COMPLETED:
   ```sh
   uv run python 00-basic-sql/cp_flink_kafka_employees_demo.py
   ```
   That creates Kafka tables (kubectl apply), then runs the employee_count DML from `cp-flink/dml.employee_count.sql`.

2. **Submit the SQL via the REST API (curl)**  
   Port-forward CMF so the API is reachable at `http://localhost:8084`:
   ```sh
   kubectl port-forward svc/cmf-service 8084:80 -n confluent
   ```
   Then POST a Statement (replace the `statement` value with the contents of your SQL file, or a one-liner):
   ```sh
   ENV_NAME=dev-env
   CMF_URL=http://localhost:8084
   # Single line of SQL for the request body (escape quotes if needed)
   SQL='WITH deduplicated_employees AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id DESC) AS row_num FROM employees WHERE row_num = 1) SELECT COALESCE(dept_id, 0) AS dept_id, COUNT(*) AS emp_count FROM deduplicated_employees GROUP BY dept_id'
   curl -s -X POST "${CMF_URL}/cmf/api/v1/environments/${ENV_NAME}/statements" \
     -H "Content-Type: application/json" \
     -d "{\"apiVersion\":\"cmf.confluent.io/v1\",\"kind\":\"Statement\",\"metadata\":{\"name\":\"employee-count\"},\"spec\":{\"statement\":\"${SQL}\",\"computePoolName\":\"pool1\",\"properties\":{\"sql.current-catalog\":\"dev-catalog\",\"sql.current-database\":\"kafka-db\"}}}"
   ```
   Check status: `curl -s "${CMF_URL}/cmf/api/v1/environments/${ENV_NAME}/statements/employee-count" | jq .status`

   The exact SQL in the request must match what your Flink catalog expects (e.g. table names, schema). For the full `dml.employee_count.sql` content (including any `ALTER TABLE` / `CREATE` if present), read the file and put it into the `statement` field (as a single line or escaped).

3. **Confluent Flink UI / CLI**  
   If your Confluent Platform or CMF deployment exposes a Flink SQL UI or the Confluent CLI for Flink, you can run SQL from there after reaching the UI (e.g. via the same CMF port-forward or a dedicated port). See Confluent documentation for your version.

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
