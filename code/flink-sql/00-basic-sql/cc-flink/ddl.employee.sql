CREATE TABLE employees (
    emp_id INT,
    name VARCHAR,
    dept_id INT,
    PRIMARY KEY(emp_id) NOT ENFORCED
) DISTRIBUTED BY HASH(emp_id) INTO 1 BUCKETS
  WITH ( 
  'changelog.mode' = 'append',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'scan.bounded.mode' = 'unbounded',
  'kafka.cleanup-policy' = 'delete',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);