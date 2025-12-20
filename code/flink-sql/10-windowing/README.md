# Example of processing event with time windows

## Find the amount of orders for one minute intervals (tumbling window aggregation)

* Create a deduplicated orders from the CC Flink examples.marketplace.orders ([see create_unique_oder.sql](./cc-flink/create_unique_oder.sql)). Then use Tumbling windows as:
```sql
SELECT
 window_time,
 COUNT(DISTINCT order_id) AS num_orders
FROM TABLE(
   TUMBLE(TABLE unique_orders, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTES))
GROUP BY window_start, window_end, window_time;
```

See [order_per_minute.sql](./cc-flink/order_per_minute.sql).

In a window operation, we should always `GROUP BY` `window_start`, `window_end` and `window_time` (defines the rowtime column of the resulting table).

## Hoping window: Compute the amount of orders per 10 minute intervals advanced by five minutes

```sql
SELECT
    window_start, 
     window_end,
    window_time,
    COUNT(DISTINCT order_id) AS num_orders
FROM TABLE(
   HOP(TABLE unique_orders, DESCRIPTOR(`$rowtime`), INTERVAL '5' MINUTES, INTERVAL '10' MINUTES))
GROUP BY window_start, window_end, window_time;
```
