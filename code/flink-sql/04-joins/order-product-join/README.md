# Order-Product Join

Join a high-velocity `orders` stream to a slowly-changing `products` reference table. The demo walks through inner join, left join, state TTL hints, and materialising the result into an `enriched_orders` Kafka topic on Confluent Cloud.

Based on [Confluent's "Join a stream to a stream" tutorial](https://developer.confluent.io/tutorials/join-a-stream-to-a-stream/flinksql.html), adapted for Confluent Cloud Flink.

## Business Problem

- `orders` is a high-velocity append log; `products` is a reference table updated weekly.
- We want to enrich each order with its product name.
- Without state TTL the join state grows unbounded — this demo shows how to control it.

## Key Concepts

| Concept | Description |
|---------|-------------|
| Inner join | Acts like a cartesian join: both sides are held in state and retracted/re-emitted on updates |
| Left join | Emits unmatched orders immediately with `NULL` for missing product fields |
| State TTL | `SET 'sql.state-ttl' = '2d'` or per-side `STATE_TTL` hint limits state growth |
| Changelog sink | A CTAS with a primary key materialises the join result as an upsert Kafka topic |

## Layout

```
cc-flink/    Confluent Cloud Flink SQL (DDL, DML, deploy manifest)
cc_dbt/      dbt-confluent model for enriched_orders
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool configured
2. Deployment credentials set up in `../../../tools/` — see its `README.md`

## Run (Confluent Cloud)

```sh
cd cc-flink

# 1. Sync statements
make sync

# 2. Create tables (no watermarks)
make deploy-ddls

# 3. Seed data
make deploy-data

# 4. Run the inner join (or paste the SQL into a Confluent Cloud Workspace cell)
make deploy-op_join_1

# 5. Alternatively run the left-join CTAS pipeline
make deploy-op_left_join

# 6. Tear down
make undeploy
make drop-tables
```

## Key SQL

### Inner join
```sql
select
  o.id as order_id,
  o.total_amount,
  o.customer_name,
  o.order_ts_raw,
  o.product_id,
  p.product_name
from d04_orders o
join d04_products p on o.product_id = p.id;
```

### Left join with per-side TTL
```sql
select /*+ STATE_TTL(o='2h', p='30d') */
  o.id as order_id,
  o.total_amount,
  o.customer_name,
  o.order_ts_raw,
  o.product_id,
  p.product_name
from d04_orders o
left join d04_products p on o.product_id = p.id;
```

## Expected Results

- With the inner join, order 9 initially shows `NULL` for `product_name` because product 4 has not been inserted yet. Inserting product 4 triggers a retraction and re-emit with the correct name.
- With the left join, order 11 appears immediately with `NULL` product name; it is updated when product 5 is later inserted — generating a delete + insert pair in the Kafka topic.

See the changelog screenshot: `../docs/order_product_joins.png`

## Watermark Variant

To run the same demo with watermark-enabled tables (required before moving to `temporal-join`):

```sh
make deploy-ddls_wm
make deploy-data
```

Watermarks do **not** affect regular equi-join or left-join results — they only matter for interval/temporal joins. See [temporal-join](../temporal-join/README.md) for that demo.
