# Confluent Cloud — Historical + Fresh Mix

## Goal

Merge bulk historical usage snapshots with live usage events. Live rows take precedence for matching keys.

## Deploy order

```sh
make sync
make deploy-ddl      # usage_snapshots, usage_events, unified_user_usage
make deploy-pipeline # dml.mix_usage.sql
```

## Test queries

```sql
SELECT source_type, COUNT(*) FROM unified_user_usage GROUP BY source_type;

SELECT user_id, product_id, feature_id, usage_count, source_type
FROM unified_user_usage
WHERE user_id IN ('user_001', 'user_002', 'user_010')
ORDER BY user_id, product_id, feature_id;
```

After snapshots only, expect `source_type = 'snapshot'` for all rows. After live events for `user_001`–`user_005`, those keys flip to `source_type = 'live'`.

## Undeploy

```sh
make undeploy-pipeline
make drop-tables
```

See [../README.md](../README.md) for producer commands and expected behavior.
