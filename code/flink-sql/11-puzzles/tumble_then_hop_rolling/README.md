# Two-stage aggregation: tumble buckets, then hop

This study explains a state-friendly pattern for rolling features: first collapse high-volume events into non-overlapping tumbling buckets per key, then run a hopping window on that compact series. Shorter lookbacks are computed with conditional aggregates inside the same hop, so you do not need one hop operator per horizon.

## Quick start

From this directory, with a local Flink cluster running ([parent readme](../readme.md)):

```sh
/path/to/flink/bin/sql-client.sh -f rolling_from_hourly_buckets.sql
```

Or use the Docker one-liner under [Where to run it](#where-to-run-it).

## Problem

You need metrics over long lookbacks (for example 30 days) on a dense event stream, but you also want a fixed output cadence (for example every 6 hours) and several nested horizons (1d, 3d, 7d, 30d). Applying a large hop directly on raw rows makes each event participate in many overlapping windows, which grows **state and shuffle**.

## Pattern

1. **Stage A — tumble (pre-aggregate):** `TUMBLE` on event time with a coarse step (for example 6 hours). Per group key you keep at most **one bucket row per interval** with aggregates (`SUM`, `COUNT`, `MAX`, sums of squares for std dev, and so on).
2. **Stage B — hop on buckets:** `HOP` on the bucket table’s time column with **slide equal to the tumble size** and **size equal to the longest lookback**. Each emitted row still aligns to the same grid, but each evaluation touches **O(long_horizon / bucket_size)** bucket rows instead of every raw event.
3. **Nested horizons in one hop:** For the **full** hop range, use plain `SUM` / `MAX` over buckets in the window. For **shorter** ranges, use `SUM(CASE WHEN bucket_end >= window_end - INTERVAL '…' THEN … END)` (and the same for `MAX` on per-bucket maxima, and so on) so shorter windows are **slices** of the same hop grouping.

**Alignment rule:** When **hop slide = tumble size**, bucket boundaries line up with hop slides so the compact time series stays consistent with the desired output cadence.

## Tradeoffs

- **Latency:** Features are only as fresh as the **tumble** step; you trade micro-batch coarseness for cheaper long windows.
- **Semantics:** Aggregates are **exact** at bucket granularity; within a bucket you lose per-event ordering for metrics that are not additive (the production query stays additive or uses bucket-level `MAX` / `sumsq` tricks).
- **Skew:** Heavy keys still dominate; the production query also filters hot `clientPoId` values to reduce skew (not repeated in the toy SQL).

## Toy example

See [`rolling_from_hourly_buckets.sql`](rolling_from_hourly_buckets.sql): **1 hour** tumbling buckets, then **12 hour** hop with **1 hour** slide; **6 hour** and **12 hour** counts and amount sums. Source is bounded **datagen** so you can run it locally in the SQL Client without CSV paths.

## Where to run it

Use the same environment as the parent [puzzle readme](../readme.md) (Flink binary or Kubernetes, for example Flink 2.1.x and `sql-client.sh`).

Start the cluster before running the script from a file (`sql-client.sh -f`). With `sql-client.sh embedded -f`, some environments return `Connection refused` when the job is submitted; a local `start-cluster.sh` session avoids that.

Example (Docker, Flink 2.1.1 image):

```sh
docker run --rm -v "$(pwd)":/opt/flink/sql apache/flink:2.1.1-scala_2.12 bash -c \
  "/opt/flink/bin/start-cluster.sh && sleep 15 && /opt/flink/bin/sql-client.sh -f /opt/flink/sql/rolling_from_hourly_buckets.sql && sleep 45 && /opt/flink/bin/stop-cluster.sh"
```

Run the command from this directory so `$(pwd)` mounts these SQL files at `/opt/flink/sql/`.

## See also

- [Windowing overview](../../10-windowing/README.md) for basic `TUMBLE` and `HOP` syntax.
