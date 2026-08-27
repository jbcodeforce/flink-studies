-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
{{ config(
    contract={'enforced': true}
) }}

WITH ranked_hosts AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY host_id
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
    FROM
        {{ source('raw_hosts', 'raw_hosts') }}
    WHERE host_id IS NOT NULL
)
SELECT
    host_id,
    host_name,
    is_superhost,
    created_at,
    updated_at
FROM
    ranked_hosts
WHERE
    row_num = 1
