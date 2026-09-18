# Temporal / Interval Join

Join a materialized `d04_order_product_join` view to a `d04_shipments` stream using an **interval (time-bounded) inner join**. Only shipments that arrive within 2 days of the corresponding order are emitted.

This demo also illustrates how watermarks affect time-based joins — unlike regular equi-joins, the interval join operator uses watermarks to decide when it is safe to emit (or discard) a buffered record.

## Business Problem

Detect whether each order was shipped within the SLA window of 2 days. Orders with shipments outside the window are silently dropped (use a left join if you need to capture late shipments).

## Key Concepts

| Concept | Description |
|---------|-------------|
| Interval join | `s.ship_ts BETWEEN o.order_ts AND o.order_ts + INTERVAL '2' DAY` — both sides must match within the time bound |
| Watermarks | Required on both input sides; Flink uses them to determine when buffered rows can be safely discarded |
| Watermark latency | Larger interval bounds increase the buffering window and downstream latency |
| `TIMESTAMPDIFF` | Used to compute hours between order and shipment for reporting |

> **Note**: Run `order-product-join` first to create `d04_order_product_join`, which this demo reads as its left input.

## Layout

```
cc-flink/    Confluent Cloud Flink SQL (DDL, DML, deploy manifest)
docs/        Diagrams (watermark-level.png, shipment_joins.png)
```

## Prerequisites

1. `order-product-join` deployed and running (provides `d04_order_product_join`)
2. Confluent Cloud environment with a Flink compute pool configured
3. Deployment credentials in `../../../tools/`

## Run (Confluent Cloud)

```sh
cd cc-flink

# 1. Sync statements
make sync

# 2. Create watermark-enabled tables
make deploy-ddl

# 3. Seed shipment data
make deploy-data

# 4. Start the interval join pipeline
make deploy-pipeline

# 5. Tear down
make undeploy
make drop-tables
```

## Key SQL

```sql
SELECT
  o.order_id,
  o.total_amount       AS total,
  o.customer_name      AS customer,
  s.id                 AS shipment_id,
  s.ship_ts_raw        AS shipment_ts,
  s.warehouse,
  TIMESTAMPDIFF(HOUR, o.order_ts_raw, s.ship_ts_raw) AS hr_to_ship
FROM d04_order_product_join o
INNER JOIN d04_shipments s
  ON  o.order_id = s.order_id
  AND s.ship_ts_raw
      BETWEEN o.order_ts_raw
          AND o.order_ts_raw + INTERVAL '2' DAY;
```

## Expected Results

Only 8 of 10 records are emitted — orders 9 and 10 have shipment timestamps more than 2 days after the order and are excluded by the interval bound.

See the diagram: `../../docs/shipment_joins.png`

## Watermark Behaviour

Watermarks on both input streams control when the join operator discards buffered rows. The propagated watermark is delayed by the maximum join interval bound (`2 DAY`), so large intervals increase buffering and tail latency.

See the diagram: `../../docs/watermark-level.png`
