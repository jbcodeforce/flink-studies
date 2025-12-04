insert into orders_with_currency_rates 
SELECT
     order_id,
     price,
     orders.currency,
     order_time,
     currency_rates.conversion_rate,
     price * currency_rates.conversion_rate as usd_converted_amount
FROM orders
LEFT JOIN currency_rates FOR SYSTEM_TIME AS OF orders.order_time
ON orders.currency = currency_rates.currency;