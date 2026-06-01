-- Regular (non-temporal) upsert join: product catalog updates re-emit matching open cart lines.
-- Re-aggregate to cart-level snapshot with nested product array and total price.
INSERT INTO integrated_cart (cart_id, user_id, cart_status, cart_date, total_price, products)
SELECT
    c.cart_id,
    MAX(c.user_id) AS user_id,
    MAX(c.cart_status) AS cart_status,
    MAX(c.cart_date) AS cart_date,
    SUM(COALESCE(p.price, CAST(0 AS DECIMAL(10, 2))) * c.quantity) AS total_price,
    ARRAY_AGG(
        ROW(c.product_id, p.name, p.price, p.availability, c.quantity)
    ) AS products
FROM cart_line_items AS c
LEFT JOIN products AS p ON c.product_id = p.product_id
WHERE c.cart_status <> 'CLOSED'
  AND c.quantity > 0
GROUP BY c.cart_id;
