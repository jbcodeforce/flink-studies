-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
{{ config(
    contract={'enforced': true}
) }}

WITH ranked_reviews AS (
     SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY listing_id
            ORDER BY `date` DESC
        ) AS row_num
    FROM
        {{ source('raw_reviews', 'raw_reviews') }}
    WHERE listing_id IS NOT NULL
)
SELECT
    listing_id,
    `date` AS review_date,
    reviewer_name,
    comments AS review_text,
    sentiment AS review_sentiment
FROM
    ranked_reviews