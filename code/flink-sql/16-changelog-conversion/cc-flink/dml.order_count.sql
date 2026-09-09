insert into d16_order_count
SELECT product_id, SUM(quantity) AS cnt
FROM d16_orders
GROUP BY product_id;