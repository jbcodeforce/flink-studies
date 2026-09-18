# Currency / FX Temporal Join

Convert trade notional amounts to a target currency using the FX rate that was **active at the moment the trade occurred** — not the rate at query time. This is the canonical use-case for Flink SQL's `FOR SYSTEM_TIME AS OF` temporal join.

## Business Problem

A trading platform records FX trades with `notional_amount` in the base currency. A market-data feed publishes FX rate ticks on the `fx_rates` topic as each tick arrives. Downstream risk and P&L systems need each trade enriched with the exact rate at trade time — using today's rate produces incorrect historical valuations.

## Architecture

![](./docs/shipment_joins.png)

---

## Common Pitfalls — Why the Query May Produce No Results

### Pitfall 1 — `valid_from` in the PRIMARY KEY (produces the PK constraint error)

Adding the version column to the primary key:

```sql
-- ✗ Wrong — triggers:
--   "Temporal table's primary key [from_currency,to_currency,valid_from] must be
--    included in the equivalence condition of temporal join"
PRIMARY KEY (from_currency, to_currency, valid_from) NOT ENFORCED
```

Flink requires the `ON` condition of a temporal join to equi-join on **every PK column**. With `valid_from` in the PK, Flink demands `AND t.trade_ts = f.valid_from` in the join condition — which is not a point-in-time lookup anymore; it is an exact-timestamp match that will almost never hit.

**Fix**: Keep the PRIMARY KEY on the *dimension identity* columns only. Confluent Cloud Flink uses the timestamp as defined by the watermark strategy  for versioning.

Use `changelog.mode = 'append'` — every rate tick is a new immutable row so the full history is preserved in the topic.

---

## Topic Configuration

### `fx_rates` — versioned reference (append + compact)

| Property | Value | Rationale |
|---|---|---|
| `cleanup.policy` | `compact` | Compact retains the latest value per Kafka key; with `append` mode each `(from_ccy, to_ccy)` key is written repeatedly so all versions survive until `retention.time` expires |
| `retention.time` | `0` (infinite) | Old rate rows must never expire; the temporal join reads historical `$rowtime` versions when enriching trades |
| `changelog.mode` | `append` | Each tick is a new immutable row; the full history is required for point-in-time lookups |
| Partitions | 4 | ~200 currency pairs → low volume; 4 is sufficient |

### `trades` — append log

| Property | Value | Rationale |
|---|---|---|
| `cleanup.policy` | `delete` | Standard append log |
| `retention.time` | `604_800_000` ms (7 days) | Must be ≥ `STATE_TTL` on the probe side so late trades can still find their rate |
| Partitions | 6–24 | Scale with trade throughput |

### `converted_trades` — enriched sink

| Property | Value | Rationale |
|---|---|---|
| `cleanup.policy` | `delete` | Downstream consumers replay from offsets |
| `retention.time` | `604_800_000` ms (7 days) | Match trades retention |
| Partitions | Match `trades` | Avoid downstream repartitioning |

---

## Data Cardinality Notes

| Table | Cardinality | State impact |
|---|---|---|
| `fx_rates` | ~200 pairs × N versions (one row per tick) | **Bounded** — Flink's versioned store retains only the snapshot needed by the current probe watermark; no unbounded growth |
| `trades` | High throughput (10 k–500 k/s typical) | **Bounded by `STATE_TTL`** — probe records wait in state until the watermark advances past `trade_ts`; set `STATE_TTL` = Kafka retention of `trades` |
| `converted_trades` | 1:1 with `trades` (INNER); ≤1:1 (LEFT) | Sink throughput mirrors input |


---

## Key Concepts

| Concept | Description |
|---|---|
| `FOR SYSTEM_TIME AS OF t.trade_ts` | Picks the `fx_rates` row with the largest `valid_from ≤ t.trade_ts` — a true point-in-time snapshot |
| Versioned table requirements | PRIMARY KEY + WATERMARK  column + `changelog.mode = 'append'` |
| Watermark dependency | The join emits only once the watermark on `trades` advances past `trade_ts`; a stalled watermark holds all results |
| INNER vs LEFT JOIN | INNER drops trades with no matching rate; LEFT passes them through with `NULL` rate |
| `STATE_TTL` hint | `/*+ STATE_TTL('t'='7d') */` on the probe alias prevents late-arriving trades from holding state forever |
| Determinism | Results are reproducible on restart — the rate is pinned to `trade_ts`, not to wall-clock time |

---

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
2. Deployment credentials in environment variables

---

## Run (Confluent Cloud)

```sh
cd cc-flink

# 1. Register statements
make sync

# 2. Create tables
make deploy-ddl

# 3. Seed FX rates (must run BEFORE the pipeline so rates exist when trades are processed)
make deploy-data

# 4. Start the conversion pipeline
make deploy-pipeline

# 5. Validate with a snapshot query:
make snapshot TABLE=converted_trades

# 6. Tear down
make undeploy
```

> **Order matters**: deploy `fx_rates` seed data before starting the pipeline, and start the pipeline before inserting trades. This ensures the versioned dimension table is populated before any trade watermark is evaluated.

---

## Expected Results

'''sh
trade_id | trade_ts                  | base_currency | quote_currency | notional_amount | fx_rate    | fx_rate_valid_from        | fx_source | converted_amount | trader_id | desk     
---------+---------------------------+---------------+----------------+-----------------+------------+---------------------------+-----------+------------------+-----------+----------
TRD-006  | 2024-06-01 09:00:00+00:00 | JPY           | USD            | 10000000.00     | 0.00642000 | 2024-06-01 08:00:00+00:00 | internal  | 64200.0000       | trader_d  | FX-APAC  
TRD-005  | 2024-06-01 15:00:00+00:00 | GBP           | USD            | 120000.00       | 1.27300000 | 2024-06-01 08:00:00+00:00 | Reuters   | 152760.0000      | trader_c  | FX-London
TRD-002  | 2024-06-01 13:30:00+00:00 | EUR           | USD            | 50000.00        | 1.08500000 | 2024-06-01 08:00:00+00:00 | ECB       | 54250.0000       | trader_b  | FX-EMEA  
TRD-008  | 2024-06-01 08:30:00+00:00 | CHF           | USD            | 30000.00        | 1.12400000 | 2024-06-01 07:30:00+00:00 | Reuters   | 33720.0000       | trader_e  | FX-EMEA  
TRD-001  | 2024-06-01 09:15:00+00:00 | EUR           | USD            | 100000.00       | 1.08500000 | 2024-06-01 08:00:00+00:00 | ECB       | 108500.0000      | trader_a  | FX-EMEA  
TRD-004  | 2024-06-01 10:00:00+00:00 | GBP           | USD            | 75000.00        | 1.27300000 | 2024-06-01 08:00:00+00:00 | Reuters   | 95475.0000       | trader_c  | FX-London
TRD-003  | 2024-06-01 17:00:00+00:00 | EUR           | USD            | 250000.00       | 1.08500000 | 2024-06-01 08:00:00+00:00 | ECB       | 271250.0000      | trader_a  | FX-EMEA  
TRD-009  | 2024-06-01 16:00:00+00:00 | CHF           | USD            | 80000.00        | 1.12400000 | 2024-06-01 07:30:00+00:00 | Reuters   | 89920.0000       | trader_e  | FX-EMEA  
TRD-007  | 2024-06-01 11:00:00+00:00 | JPY           | USD            | 5000000.00      | 0.00642000 | 2024-06-01 08:00:00+00:00 | internal  | 32100.0000       | trader_d  | FX-APAC  
'''

