CREATE TABLE order_volumes AS WITH orders_with_details AS (
  SELECT
    o.order_id,
    s.dimensions.length,
    s.dimensions.height,
    s.dimensions.width,
    o.`$rowtime`
  FROM
    orders o
    CROSS JOIN UNNEST(o.product_ids) AS p(id)
    LEFT JOIN `product_details` FOR SYSTEM_TIME AS OF o.`$rowtime` s ON s.`product_id` = p.`id`
)
SELECT
  AVG(
    CAST(SPLIT_INDEX(LENGTH, 'c', 0) AS DOUBLE) * CAST(SPLIT_INDEX(width, 'c', 0) AS DOUBLE) * CAST(SPLIT_INDEX(height, 'c', 0) AS DOUBLE)
  ) AS avg_volume,
  window_time,
  o.order_id
FROM
  TABLE(
    TUMBLE(
      TABLE `orders_with_details`,
      DESCRIPTOR($rowtime),
      INTERVAL '1' MINUTE
    )
  ) o
GROUP
  BY window_start,
  window_end,
  window_time,
  o.order_id;