# Joins — Flink SQL Demo Catalog

This directory contains a collection of Flink SQL demos exploring different join patterns, from basic equi-joins to temporal joins, self-joins, and advanced real-world scenarios on Confluent Cloud.

Each sub-demo is self-contained with its own `README.md` explaining the business problem and how to run it. Confluent Cloud demos use the shared deployment tooling under `../tools/` via a `deploy_manifest.json` and a `Makefile`.

---

## Sub-Demos

| Demo | Intent | Join type(s) |
|------|--------|--------------|
| [order-product-join](./order-product-join/README.md) | Join a high-velocity `orders` stream to a slowly-changing `products` reference table. Walks through inner join, left join, state TTL hints (`STATE_TTL`), and materialising the result as an `enriched_orders` upsert topic. Also includes a dbt-confluent variant (`cc_dbt/`). | Inner join, Left join |
| [temporal-join](./temporal-join/README.md) | Join `orders` to `shipments` using a time-bounded **interval join** (`BETWEEN order_ts AND order_ts + INTERVAL '2' DAY`). Shows how watermarks control buffering and when records are safely emitted or discarded. | Interval join |
| [advanced-exercises](./advanced-exercises/README.md) | 16 hands-on exercises using the Confluent Cloud `examples.marketplace` dataset. Covers tumbling-window aggregations, `CROSS JOIN UNNEST` on array columns, point-in-time temporal joins, UDF authoring, and session identification. | Mixed (tumble window, temporal, UNNEST) |
| [data-skew](./data-skew/README.md) | Demonstrates how a skewed join key causes a hotspot on one task-manager subtask, then shows the **salted-join** mitigation: append a random salt to the probe side and replicate the reference side N times so the load is spread evenly. | Equi-join, Salted join |
| [inner-join-with-dedup](./inner-join-with-dedup/README.md) | Classical entity → entityType management pattern. CDC topics re-send the full record on every update, creating duplicates. Uses `ROW_NUMBER() OVER (PARTITION BY … ORDER BY ts DESC)` to keep only the latest version, then inner-joins the deduplicated streams to produce a flat enriched asset record. Also shows `ARRAY_AGG` to roll up multiple subtypes per asset. | Inner join + Dedup |
| [group-users](./group-users/README.md) | Models a multi-level group/person hierarchy (Region → Hospital → Department → Team → Person) entirely in Flink SQL using **self-joins** and `UNION ALL` (Flink does not support `WITH RECURSIVE`). A second pattern handles soft-deletion: a tombstone event marks all members of a group as deleted unless a newer event re-instates them. | Self-join |
| [event-status-processing](./event-status-processing/README.md) | Tracks CDC event status transitions (`eventProcessed` flipping from `false` to `true`) on a single topic. Early-stage demo — the DDL is defined; the pipeline SQL is a work-in-progress. | Self-join / CDC join |
| [rule-match-on-sensors](./rule-match-on-sensors/README.md) | Applies per-tenant device threshold rules to a real-time sensor stream using `FOR SYSTEM TIME AS OF s.created_at` — a temporal join that looks up the rule version active at the exact moment each sensor reading was produced. | Temporal join (point-in-time lookup) |
| [currency-temporal-join](./currency-temporal-join/README.md) | FX/currency conversion: enrich each trade with the exchange rate that was active **at trade time** using `FOR SYSTEM TIME AS OF`. Covers compact-topic configuration for the rates reference table, infinite retention rationale, `STATE_TTL` sizing, and data cardinality analysis. Includes INNER and LEFT JOIN variants and a full expected-results table. | Temporal join (`FOR SYSTEM TIME AS OF`) |
| [self-joins](./self-joins/README.md) | Music-streaming domain. A generic event envelope carries two payload types (`subscription`, `deviceSwap`). The demo resolves `account_number → party_id` via a reference-table join on a compact topic, expands all accounts for that party, and self-joins the event stream to attach sibling `deviceSwap` details. Python Kafka producers are included. | Self-join, Reference join |

---

## Common Prerequisites

All `cc-flink/` demos require:

1. A Confluent Cloud environment with a Flink compute pool configured
2. Credentials set up in `../tools/` — see its `README.md`
3. `make sync` run once from each `cc-flink/` directory to register SQL statements

## Deployment Pattern

Every `cc-flink/` subfolder follows the same workflow:

```sh
cd <demo>/cc-flink

make sync             # register statements with Confluent Cloud
make deploy-ddl       # create tables
make deploy-data      # seed data (optional)
make deploy-pipeline  # start streaming jobs

make undeploy         # stop jobs
make drop-tables      # delete tables
```

The `deploy_manifest.json` in each `cc-flink/` folder defines the statement groups and their deployment order.
