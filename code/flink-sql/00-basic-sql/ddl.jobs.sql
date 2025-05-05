CREATE TABLE jobs (
	job_id SERIAL,
	job_title CHARACTER VARYING (35) NOT NULL,
	min_salary NUMERIC (8, 2),
	max_salary NUMERIC (8, 2),
    PRIMARY KEY(job_id) not enforced
);