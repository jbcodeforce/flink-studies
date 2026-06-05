{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_customers_pk',
    tags=['crm'],
    with={
        'changelog.mode': 'upsert',
    },
    post_hook=[
        "ALTER TABLE {{ this }} MODIFY WATERMARK FOR `created_at` AS `created_at` - INTERVAL '5' SECONDS",
        "ALTER TABLE {{ this }} ADD (
            `record_headers` MAP<STRING, BYTES> METADATA FROM 'headers',
            `record_leader_epoch` INT METADATA FROM 'leader-epoch',
            `record_offset` BIGINT METADATA FROM 'offset',
            `record_partition` INT METADATA FROM 'partition',
            `record_key` BYTES METADATA FROM 'raw-key',
            `record_value` BYTES METADATA FROM 'raw-value',
            `record_timestamp` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp',
            `record_timestamp_type` STRING METADATA FROM 'timestamp-type',
            `record_topic` STRING METADATA FROM 'topic'
        )",
        "ALTER TABLE {{ this }} SET ('kafka.consumer.isolation-level'='read-uncommitted')",
    ],
) }}

select * from {{ ref('customers_faker') }}
