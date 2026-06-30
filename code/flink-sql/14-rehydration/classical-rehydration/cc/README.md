# Confluent Cloud — Classical Rehydration

## Goal

Stream append usage events into a compact upsert summary table. Replay from earliest offset to rehydrate state after deploy or restart.

## Deploy order

```sh
make sync
make deploy-ddl      # usage_events + user_usage_summary
make deploy-pipeline # dml.rehydrate_usage.sql
```

## Test queries

```sql
SELECT * FROM usage_events LIMIT 20;

SELECT * FROM user_usage_summary ORDER BY total_usage DESC LIMIT 20;

SELECT user_id, COUNT(*) AS feature_count, SUM(total_usage) AS user_total
FROM user_usage_summary
GROUP BY user_id
ORDER BY user_total DESC;
```

## Undeploy

```sh
make undeploy-pipeline
make drop-tables
```

See [../README.md](../README.md) for producer commands and expected behavior.
