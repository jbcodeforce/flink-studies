-- Temporal / Interval Join: orders <-> shipments
-- Emits matched records where the shipment arrives within 2 days of the order.
-- Requires watermark-enabled tables (ddl.orders_wm.sql, ddl.products_wm.sql, ddl.shipments.sql)
-- and the d04_order_product_join view to already exist (deploy from order-product-join first).

SELECT
  o.order_id                                          AS order_id,
  o.total_amount                                      AS total,
  o.customer_name                                     AS customer,
  s.id                                                AS shipment_id,
  s.ship_ts_raw                                       AS shipment_ts,
  s.warehouse,
  TIMESTAMPDIFF(HOUR, o.order_ts_raw, s.ship_ts_raw)  AS hr_to_ship
FROM d04_order_product_join o
INNER JOIN d04_shipments s
  ON  o.order_id = s.order_id
  AND s.ship_ts_raw
      BETWEEN o.order_ts_raw
          AND o.order_ts_raw + INTERVAL '2' DAY;
