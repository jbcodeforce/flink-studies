create table `raw-jobs` (
    job_id BIGINT,
    order_id BIGINT,
    job_type STRING,
    job_status STRING,
    rate_service_provider STRING,
    total_paid DECIMAL(10,2),
    job_date_start STRING,
    job_completed_date STRING,
    job_entered_date STRING,
    job_last_modified_date STRING,
    service_provider_name STRING
) distributed by hash(job_id) into 1 buckets WITH (
   'value.avro-registry.schema-context' = '.dev',
   'kafka.retention.time' = '0',
    'changelog.mode' = 'append',
   'scan.bounded.mode' = 'unbounded',
   'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all'
)