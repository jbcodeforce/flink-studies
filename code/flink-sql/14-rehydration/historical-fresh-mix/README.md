# Historical + Fresh Mix — SaaS Usage

Combine bulk historical usage snapshots with a live event stream into one unified current-state view.

## Pattern

```
usage_snapshots (historical) ──┐
                               ├── UNION ALL → ROW_NUMBER (live wins) → unified_user_usage (upsert)
usage_events (live) ───────────┘
```

Live rows override snapshot rows for the same `(user_id, product_id, feature_id)` key. Users that only appear in snapshots retain snapshot totals.

## Kafka topics

- `usage-snapshots` — bulk historical export
- `usage-events` — live incremental usage

## Deploy

```sh
cd cccloud
make sync && make deploy-ddl && make deploy-pipeline
```

## Produce test data

Load snapshots before live events:

```sh
cd ../python && uv sync
source ../../../../set_env.sh

# Bulk historical load (150 rows across 50 users x 3 products x 3 features)
uv run producers/produce_usage_snapshots.py --count 150 --interval 0

# Live updates for user_001 .. user_005 (overlap with snapshots)
uv run producers/produce_usage_events.py --count 15
```

## Validation queries

```sql
-- Source counts
SELECT COUNT(*) FROM usage_snapshots;
SELECT COUNT(*) FROM usage_events;

-- Mix result by source
SELECT source_type, COUNT(*) AS row_count
FROM unified_user_usage
GROUP BY source_type;

-- Live overrides: users with live events
SELECT * FROM unified_user_usage
WHERE source_type = 'live'
ORDER BY usage_count DESC;

-- Snapshot-only users (no live override)
SELECT * FROM unified_user_usage
WHERE source_type = 'snapshot'
  AND user_id NOT IN (
    SELECT user_id FROM unified_user_usage WHERE source_type = 'live'
  )
LIMIT 20;
```

## Expected results

- Before live events: all rows in `unified_user_usage` have `source_type = 'snapshot'`.
- After live events: keys touched by live producers show `source_type = 'live'` with updated `usage_count` (typically 100–500 from the live producer).
- Keys for `user_006` and above remain `source_type = 'snapshot'` with original snapshot counts (10–99 range).

## Files

| File | Purpose |
|------|---------|
| `cccloud/ddl.usage_snapshots.sql` | Historical bulk source |
| `cccloud/ddl.usage_events.sql` | Live append source |
| `cccloud/ddl.unified_user_usage.sql` | Unified upsert sink |
| `cccloud/dml.mix_usage.sql` | UNION ALL + live-wins dedup pipeline |
| `python/producers/produce_usage_snapshots.py` | Bulk snapshot producer |
| `python/producers/produce_usage_events.py` | Live event producer |
