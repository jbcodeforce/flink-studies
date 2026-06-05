{{ config(
    materialized='streaming_table',
    enabled=var('crm_enable_mongodb', false),
    statement_name='fw_crm_customer_movies_lookup',
    tags=['crm'],
) }}

select
    customer_name,
    date_of_birth,
    search_results
from {{ ref('customers_faker') }},
    lateral table(
        key_search_agg(
            {{ ref('mongodb_movies') }},
            descriptor(`year`),
            cast(year(date_of_birth) as int)
        )
    )
