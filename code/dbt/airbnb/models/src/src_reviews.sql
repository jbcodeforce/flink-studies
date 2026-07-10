WITH ranked_reviews AS (
     SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY listing_id
            ORDER BY date DESC
        ) AS row_num
    FROM
        {{ source('airbnb', 'reviews') }}
    WHERE listing_id IS NOT NULL
)
SELECT
    listing_id,
    date AS review_date,
    reviewer_name,
    comments AS review_text,
    sentiment AS review_sentiment
FROM
    ranked_reviews