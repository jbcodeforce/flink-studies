# Flink SQL files (local gateway / reference)

SQL equivalents of the sql-executor pipeline. Used as the source for [../../cccloud/](../../cccloud/) on Confluent Cloud.

## Files

| File | Role |
|------|------|
| [ddl_source.sql](ddl_source.sql) | `perf_source` table |
| [ddl_sink.sql](ddl_sink.sql) | `perf_sink` table |
| [dml_passthrough.sql](dml_passthrough.sql) | `INSERT INTO ... SELECT` |

Replace `<BOOTSTRAP_SERVERS>` in DDL before submit.

## Local SQL client

```bash
export BOOTSTRAP_SERVERS=localhost:9092
# Submit in order via Flink SQL Gateway or sql-client.sh from deployment/
```

## Confluent Cloud

Use [../../cccloud/](../../cccloud/) (distributed-by-hash DDL for CC Flink).
