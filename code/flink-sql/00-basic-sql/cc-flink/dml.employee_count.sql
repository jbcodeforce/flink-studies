create table employee_count (
    dept_id INT NOT NULL,
    emp_count BIGINT NOT NULL,
     PRIMARY KEY(dept_id) NOT ENFORCED
) with (
 'changelog.mode' = 'upsert',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'scan.bounded.mode' = 'unbounded',
  'kafka.cleanup-policy' = 'compact',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
) as 
with deduplicated_employees as (
    select * from (
        select *,
        ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id DESC) as row_num
        from employees
    ) where row_num = 1
)
select coalesce(dept_id, 0) as dept_id, count(*) as emp_count from deduplicated_employees group by dept_id;
