-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.

{{ config(
    contract={'enforced': true}
) }}

WITH ranked_listings AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY listing_id
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
    FROM
        {{ source('raw_listings', 'raw_listings') }}
    WHERE listing_id IS NOT NULL
)
SELECT
    listing_id,
    listing_name,
    listing_url,
    room_type,
    minimum_nights,
    host_id,
    price_str,
    created_at,
    updated_at
FROM  ranked_listings