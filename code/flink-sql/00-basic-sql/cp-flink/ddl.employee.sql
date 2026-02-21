CREATE TABLE employees (
    emp_id INT,
    name VARCHAR,
    dept_id INT,
    PRIMARY KEY(emp_id) NOT ENFORCED
) WITH ( 
    'connector' = 'filesystem',
    'path' = '../data/employees.csv',
    'format' = 'csv'
);