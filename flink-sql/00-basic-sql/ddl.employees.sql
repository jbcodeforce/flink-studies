CREATE TABLE IF NOT EXISTS employees (
	employee_id SERIAL PRIMARY KEY,
	first_name CHARACTER VARYING (20),
	last_name CHARACTER VARYING (25) NOT NULL,
	email CHARACTER VARYING (100) NOT NULL,
	phone_number CHARACTER VARYING (20),
	hire_date DATE NOT NULL,
	job_id INT NOT NULL,
	salary NUMERIC (8, 2) NOT NULL,
	manager_id INT,
	department_id INT
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql/data/employees.csv',
    'format' = 'csv'
);