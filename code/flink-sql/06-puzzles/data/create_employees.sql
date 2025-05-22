create table employees (
    employee_id int,
    salary int
) with (
    'connector' = 'filesystem',
    'path' = '/data/employees.csv'
);