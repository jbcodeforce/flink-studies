{{ config(
    materialized='streaming_table',
    with={
        'changelog.mode': 'upsert',
        'key.format': 'avro-registry',
        'value.format': 'avro-registry',
        'scan.bounded.mode': 'unbounded',
        'kafka.cleanup-policy': 'compact',
        'scan.startup.mode': 'earliest-offset',
        'value.fields-include': 'all'
    }
) }}

-- Migrated from dml.employee_count.sql
with deduplicated_employees as (
    select * from (
        select *,
        ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id DESC) as row_num
        from {{ ref('employees') }}
    ) where row_num = 1
)
select coalesce(dept_id, 0) as dept_id, count(*) as emp_count from deduplicated_employees group by dept_id
