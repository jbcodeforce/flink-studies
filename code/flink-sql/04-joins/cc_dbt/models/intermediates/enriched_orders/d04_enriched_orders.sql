{{ config(
    materialized='streaming_table',
    with={
        'changelog.mode': 'upsert',
        'key.format': 'avro-registry',
        'value.format': 'avro-registry',
        'value.fields-include': 'all'
    }
) }}

-- Migrated from dml.enriched_orders.sql
select  /*+ STATE_TTL(o='2h', p='30d') */ 
   o.id as order_id,
   o.total_amount,
   o.customer_name,
   o.order_ts_raw,
   o.product_id,
   p.product_name
from {{ source('cc_flink', 'd04_orders') }} o
left join {{ source('cc_flink', 'd04_products') }} p on o.product_id = p.id
