# Classical Rehydration — SaaS Usage

Rebuild current usage totals from an append-only event log, then continue incremental processing.

## Pattern

```
usage_events (append) → dedup by event_id → SUM(usage_count) → user_usage_summary (upsert, compact)
```

Rehydration occurs when the pipeline reads from `earliest-offset`: the full event log replays into the upsert sink, reconstructing per-key totals.

## Kafka topics

- `usage_events` — append usage event log

## Deploy

```sh
cd cc
make sync && make deploy-ddl && make deploy-pipeline
```

## Produce test data

```sh
cd ../python && uv sync
source ../../../../set_env.sh
uv run producers/produce_usage_events.py --count 30
uv run producers/produce_usage_events.py --count 10 --with-duplicates
```

The `--with-duplicates` flag replays some `event_id` values to demonstrate dedup before aggregation.

## Validation queries

Run in Confluent Cloud Flink SQL:

```sql
-- Raw append stream
SELECT * FROM usage_events LIMIT 20;

-- Rehydrated current state
SELECT * FROM user_usage_summary ORDER BY total_usage DESC;

-- Per-user rollup
SELECT user_id, COUNT(*) AS feature_count, SUM(total_usage) AS user_total
FROM user_usage_summary
GROUP BY user_id
ORDER BY user_total DESC;
```

## Expected results

- `usage_events` contains one row per produced event (including duplicate `event_id` replays).
- `user_usage_summary` has one row per `(user_id, product_id, feature_id)` combination.
- Duplicate `event_id` rows do not double-count in `total_usage`.
- After stopping and redeploying the pipeline with `earliest-offset`, totals match a full replay of the log.

## Files

| File | Purpose |
|------|---------|
| `cc/ddl.usage_events.sql` | Append source table (`key`, raw Kafka key, json-registry value) |
| `cc/ddl.user_usage_summary.sql` | Upsert sink with compact policy |
| `cc/dml.rehydrate_usage.sql` | Continuous rehydration pipeline |
| `python/producers/produce_usage_events.py` | Test event producer |
