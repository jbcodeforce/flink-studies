SELECT $rowtime AS row_time
      , customer_id
      , order_id
      , price
      , LAG(order_id, 1) OVER (PARTITION BY customer_id ORDER BY $rowtime) previous_order_id
      , LAG(price, 1) OVER (PARTITION BY customer_id ORDER BY $rowtime) previous_order_price
  FROM examples.marketplace.orders;