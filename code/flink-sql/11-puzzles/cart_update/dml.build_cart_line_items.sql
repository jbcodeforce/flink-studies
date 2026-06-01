-- Dedup append cart events into upsert cart_line_items (latest event per cart_id + product_id).
-- REMOVE sets quantity to 0; integrated_cart filters quantity > 0.
INSERT INTO cart_line_items (cart_id, product_id, quantity, cart_status, cart_date, user_id)
SELECT
    cart_id,
    product_id,
    quantity,
    cart_status,
    cart_date,
    user_id
FROM (
    SELECT
        cart_id,
        product_id,
        CASE WHEN action = 'REMOVE' THEN 0 ELSE quantity END AS quantity,
        cart_status,
        cart_date,
        user_id,
        ROW_NUMBER() OVER (
            PARTITION BY cart_id, product_id
            ORDER BY event_ts DESC
        ) AS rn
    FROM cart_events
)
WHERE rn = 1;
