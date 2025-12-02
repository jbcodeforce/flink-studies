# Temporal joins studies

Let try [the Flink example about temporal joins](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sql/queries/joins/#temporal-joins) to join against a versioned table, on Confluent Cloud.

The join will get value of the versioned table at the event time of the probe side (LHS).

The temporal join syntax:
```sql
insert into orders_with_currency_rates 
SELECT
     order_id,
     price,
     orders.currency,
     order_time,
     currency_rates.conversion_rate,
     price * coalesce(currency_rates.conversion_rate,1) as usd_converted_amount
FROM orders
LEFT JOIN currency_rates FOR SYSTEM_TIME AS OF orders.order_time
ON orders.currency = currency_rates.currency;
```

The event-time temporal join is triggered by a watermark from the left and right sides. The INTERVAL time subtraction is used to wait for late events in order to make sure the join will meet the expectation:

```sql
CREATE TABLE orders (
    order_id    STRING,
    price       DECIMAL(32,2),
    currency    STRING,
    order_time  TIMESTAMP_LTZ(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '15' SECOND,
    PRIMARY KEY (order_id) NOT ENFORCED
) 
```

## Run the three DDLs

* Run in Confluent Cloud Workspace the `ddl.orders.sql`, `ddl.currencu_rates.sql`, and the sink table: `ddl.orders_with_curr_rate.sql`

* Use the orders as defined in `insert_orders.sql`

## First Case : no rate yet

* Run the temporal join without right side, will generate records without conversion rate:
     ```sql
     (order_id, price, currency, order_time, convertion_rate, usd_converted amount)
     ('ORD-001', 100.00, 'EUR', TIMESTAMP '2024-01-15 10:00:00', NULL, 100),
     ...
     ```

## Add one set of rates

* Now add 1 set of rate for each currency at 10:00:00: run the `insert_curr_rates_1.sql`, while the temporal join still running. --> no changes
* Stop the temporal and restart it. Now the conversion rate are gound with the match and converted amounts work:
     ```sql
     (order_id, price, currency, order_time, convertion_rate, usd_converted amount)
     ('ORD-001', 100.00, 'EUR', TIMESTAMP '2024-01-15 10:00:00', 1.16, 116),
     ...
     ```

## Adding more rates for each time slices

* Execute `insert_curr_rate_2.sql`, while the temporal join runs. -> records are not re-evaluated so the results are the same as above.
* Restarting the temporal join will get the expected results
     ```sql
     (order_id, price, currency, order_time, convertion_rate, usd_converted amount)
     ('ORD-001', 100.00, 'EUR', TIMESTAMP '2024-01-15 10:00:00', 1.16, 116),
     ('ORD-002', 250.50, 'YEN', TIMESTAMP '2024-01-15 10:05:00', 0.14, 35.07),
     ('ORD-003', 75.25, 'GBP', TIMESTAMP '2024-01-15 10:10:00', 1.32, 99.33),
     ('ORD-004', 500.00, 'JPY', TIMESTAMP '2024-01-15 10:15:00', 0.01, 5),
     ('ORD-005', 150.75, 'EUR', TIMESTAMP '2024-01-15 10:20:00', 1.17, 176.3775),
     ('ORD-006', 320.00, 'YEN', TIMESTAMP '2024-01-15 10:25:00', 0.15, 48),
     ('ORD-007', 95.50, 'GBP', TIMESTAMP '2024-01-15 10:30:00') 1.33, 127.015,
     ('ORD-008', 200.00, 'EUR', TIMESTAMP '2024-01-15 10:35:00', 1.17,  234),
     ('ORD-009', 425.80, 'YEN', TIMESTAMP '2024-01-15 10:40:00', 0.15, 63.87),
     ...
     ```