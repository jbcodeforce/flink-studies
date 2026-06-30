# Rehydration

The rehydration pattern means rebuilding current state from an event log, CDC stream, or compacted Kafka topic, then resuming incremental processing. Internal Confluent examples call out CDC rehydration as a common scenario, and also recommend compacted topics for current-state rehydration.

**Domain:** SaaS product usage (users consuming features across a product catalog).

**Deployment:** Confluent Cloud Flink SQL only (`cc/`).

## Demos

| Pattern | Folder | Summary |
|---------|--------|---------|
| Classical rehydration | [classical-rehydration/](classical-rehydration/) | Append `usage_events` log → dedup → aggregate → upsert `user_usage_summary` |
| Historical + fresh mix | [historical-fresh-mix/](historical-fresh-mix/) | Bulk `usage_snapshots` UNION ALL live `usage_events` → `unified_user_usage` (live wins) |

## Prerequisites

Set Confluent Cloud credentials (see [code/flink-sql/tools/README.md](../tools/README.md)):

```sh
source code/flink-sql/set_env.sh
```

Create Kafka topics `usage-events` and (for the mix demo) `usage-snapshots` in your environment, or let the Python producers create them.

## json-registry timestamps

With `value.format = 'json-registry'`, JSON Schema `format: date-time` fields materialize as **STRING** in Flink, not `TIMESTAMP_LTZ`. A STRING column cannot carry a `WATERMARK`.

Source DDL therefore declares:

- `event_time STRING` — matches the JSON payload / Schema Registry type
- `event_ts AS CAST(event_time AS TIMESTAMP_LTZ(3))` — computed column for ordering and watermarks
- `WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND`
- `'key.format' = 'raw'` on source tables — producers send plain UTF-8 keys (`user_id`), not Schema Registry wire format

Producers emit UTC strings as `yyyy-MM-dd HH:mm:ss.SSS` (e.g. `2026-06-29 23:51:37.231`). Flink `CAST(... AS TIMESTAMP_LTZ(3))` does not parse ISO-8601 `T`/`Z` forms. Pipelines use the computed `event_ts` column.

## Quick start

### Classical rehydration

```sh
cd code/flink-sql/14-rehydration/classical-rehydration/cc
make sync && make deploy-ddl && make deploy-pipeline

cd ../python && uv sync
uv run producers/produce_usage_events.py --count 30 --with-duplicates
```

### Historical + fresh mix

Load snapshots first, then live events:

```sh
cd code/flink-sql/14-rehydration/historical-fresh-mix/cc
make sync && make deploy-ddl && make deploy-pipeline

cd ../python && uv sync
uv run producers/produce_usage_snapshots.py --count 150 --interval 0
uv run producers/produce_usage_events.py --count 15
```


## Classical Rehydratation

Rebuild keyed usage totals by replaying the append-only event log from the earliest offset. Duplicate `event_id` values are deduplicated before aggregation. The sink table uses upsert changelog mode with compact cleanup policy for current-state storage.

See [classical-rehydration/README.md](classical-rehydration/README.md).

## Mixing historical data with fresh data

Combine a bulk historical snapshot export with a live usage stream. Rows tagged `live` override snapshot rows for the same `(user_id, product_id, feature_id)` key. Users without live events retain snapshot totals.

See [historical-fresh-mix/README.md](historical-fresh-mix/README.md).

## Related patterns elsewhere in the repo

- Append → upsert dedup: [05-changelog](../05-changelog/README.md)
- CDC envelope dedup: [cdc-dedup-transform](../../../e2e-demos/cdc-dedup-transform/)
- Materialized table `START_MODE`: [13-materialized-table](../13-materialized-table/README.md)
