CREATE TABLE employees (
    emp_id INT,
    name VARCHAR,
    dept_id INT
) WITH (
    'connector' = 'filesystem',
    'path' = './data/employees.csv',
    'format' = 'csv'
);

SET 'execution.runtime-mode' = 'batch';
CREATE TABLE department_counts (
    dept_id INT,
    emp_count BIGINT NOT NULL
) WITH ( 
    'connector' = 'filesystem',
    'path' = './data/dept_count',
    'format' = 'csv'
);

insert into department_counts
with deduplicated_employees as (
    select *  FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY emp_id 
                ORDER BY emp_id DESC
            ) AS row_num
        FROM employees
    ) WHERE row_num = 1
)
select dept_id, count(*) as emp_count from deduplicated_employees group by dept_id;
