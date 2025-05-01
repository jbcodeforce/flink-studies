create table employees (
    employ_id INT, 
    name STRING,
    salary INT,
    department_id INT
) with (
    'connector' = 'filesystem', 
    'path' = '/Users/jerome/Code/ReadOnlyRepos/flink-studies/e2e-demos/sql-gateway-demo/employees.csv',
    'format' = 'csv'
);
    