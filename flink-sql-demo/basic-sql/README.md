# Flink SQL some basic examples

Start the docker-compose in root folder of this project.

## Code to test getting started [doc example](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sql/gettingstarted/)

The employee.csv has 15 records.

The job is a batch processing: use the following DDL to create the table from the file. 

```sql
SET execution.runtime-mode=BATCH;

CREATE TABLE employee_info (
    emp_id INT,
    name VARCHAR,
    dept_id INT
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql-demo/basic-sql/data/employes.csv',
    'format' = 'csv'
);
```

Basic select to very some data: `SELECT * from employee_info WHERE dept_id = 101;`

Then count the employees per department, as a stateful query:

```sql
select dept_id, count(*) from employee_info group by dept_id;
```

The query needs to maintain the most up to date count for each department to output timely results as new rows are processed.

Add the sink table

```sql
CREATE TABLE department_counts (
    dept_id INT,
    emp_count BIGINT NOT NULL
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql-demo/basic-sql/data',
    'format' = 'csv'
);

SET 'sql-client.execution.result-mode' = 'table';

INSERT INTO department_counts
SELECT 
   dept_id,
   COUNT(*) as emp_count 
FROM employee_info
GROUP BY dept_id;
```


```sql
```