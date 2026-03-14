select
     r.listing_id,
     l.created_at,
     r.review_date
from {{ ref('fct_reviews') }} as r
left join dim_listings_cleansed as l
on r.listing_id = l.listing_id where l.created_at > r.review_date