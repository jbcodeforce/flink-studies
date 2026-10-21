# Local (OSS Apache Flink) execution

Same three queries as the `cc-flink/` variant, runnable on a local **Apache Flink SQL client** backed by a local Kafka broker. Both come from `../../docker-compose.yaml` (Flink 1.19 + KRaft Kafka).

The SQL differs from `cc-flink/` only in the DDL: OSS Flink needs an explicit `'connector' = 'kafka'` with bootstrap servers, whereas Confluent Cloud infers the backing topic.

## Files

```
ddl.project_events.sql        Kafka-backed source (local broker)
dml.match_recognize.sql       APPROACH 1 — CEP sequential pairing (append)
dml.rownumber_top1.sql        APPROACH 2 — top-1 dedup (updating changelog)
dml.cartesian_join.sql        APPROACH 3 — plain join (literal M:N, append)
tests/insert_project_events.sql   deterministic scenario (u1,t1,u2,t2,t3)
```

## Start the local stack

```sh
cd ..                      # code/flink-sql/04-joins
docker compose up -d broker flink-jobmanager flink-taskmanager flink-sql-client
docker exec -it flink-sql-client sql-client.sh
```

Flink Web UI: http://localhost:9081

## Run it (inside the SQL client)

```sql
-- show the changelog op column (+I / -U / +U) — the whole point of the demo
SET 'sql-client.execution.result-mode' = 'tableau';

-- 1. create the source (paste ddl.project_events.sql)
-- 2. seed data (paste tests/insert_project_events.sql) and WAIT for the
--    bounded INSERT job to finish before selecting
-- 3. run ONE query file at a time (paste a dml.*.sql)
```

Run the queries one at a time and compare:

| File | What you see |
|------|--------------|
| `dml.match_recognize.sql` | `+I (P,u1,t1)` then `+I (P,u2,t3)` — append-only; each match a new row |
| `dml.rownumber_top1.sql` | `+I` then `-U`/`+U` pairs — one row per project, updated in place |
| `dml.cartesian_join.sql` | all 6 `u×t` combinations as `+I` |

Because the source uses `'scan.bounded.mode' = 'latest-offset'`, each SELECT reads the seeded rows, flushes the final match on EOF, and terminates — so output is complete and deterministic rather than an open-ended stream.

## Teardown

```sh
cd ..
docker compose down
```

## Notes

- The broker auto-creates the `project_events` topic on first INSERT (single partition, which also keeps event ordering clean for `MATCH_RECOGNIZE`).
- Not yet run end-to-end on this stack — SQL is validated for syntax/semantics only. If the final `MATCH_RECOGNIZE` match does not appear, confirm the INSERT job completed before the SELECT started (so `latest-offset` includes all rows).
