# Many-to-Many Pairing: ROW_NUMBER vs MATCH_RECOGNIZE

Reproduces a scenario and clarifies the Flink SQL concept underneath it: **whether a result row is an INSERT or an UPDATE is decided by the changelog's key, not by whether the data "looks new."** The confusion usually isn't about joins — it's about keyed updating changelogs.

## The problem

> For a shared key `P`, users `{u1, u2}` and tasks `{t1, t2, t3}` arrive interleaved. The query emits `(P, u1, t1)`; it does **not** emit `(P, u2, t2)`; when `t3` arrives it emits `(P, u2, t3)` as a **new unique row** — not an update to `(P, u1, t1)`

The basic approach of using `ROW_NUMBER` to pair the two sides may not cover all requirements.

## The resolution

Three different tools give three different — all correct — behaviors. Pick by the semantics you actually want:

| You want… | Tool | Changelog | Result for project `P` |
|-----------|------|-----------|-------------------------|
| Every user × task combination (literal M:N) | plain `INNER JOIN` | append (`+I` only) | all 6 combos |
| One current row per project | `ROW_NUMBER` top-1 / `GROUP BY` | **updating** (`-U`/`+U`) | one row, retracted + replaced each time |
| Sequential pairing, each match kept forever | `MATCH_RECOGNIZE` (CEP) | append (`+I` only) | `(u1,t1)`, `(u2,t3)` — as expected |

**`MATCH_RECOGNIZE` is the "better way without a UDF."** : Flink SQL only supports `ONE ROW PER MATCH` (there is **no** `ALL ROWS PER MATCH`). A pattern `U TMID* TEND` matching `u2, (t2), t3` collapses to one row — `t2` folds into `TMID` and `TEND = t3` is reported — so `(P,u2,t3)` is emitted as an independent `+I`. It is not an update to `(P,u1,t1)` because each match has its own identity; there is no shared GROUP BY key to collide on. (The pattern ends on the simple variable `TEND` because Flink rejects a greedy quantifier such as `T+` as the last element.)


### Approach 1: plain regular join: literal many-to-many (cartesian product).

This is what "many-to-many" means to the SQL engine: every USER crossed with every TASK that shares the project. For project 'P' with users {u1,u2} and tasks {t1,t2,t3} it emits all 6 combinations as +I (append) rows: (u1,t1) (u1,t2) (u1,t3) (u2,t1) (u2,t2) (u2,t3)

Use this when you genuinely want all pairings. CAUTION: a regular (non-windowed, non-temporal) join keeps BOTH input sides in state indefinitely, so unbounded streams grow state without limit. Bound it with an interval join, a temporal join or state TTL in production.

* File [./cc-flink/dml.cartesian_join.sql](./cc-flink/dml.cartesian_join.sql)
```sql
SELECT
  u.project_id,
  u.entity_id AS user_id,
  t.entity_id AS task_id
FROM       (SELECT project_id, entity_id FROM project_events WHERE event_type = 'USER') AS u
INNER JOIN (SELECT project_id, entity_id FROM project_events WHERE event_type = 'TASK') AS t
  ON u.project_id = t.project_id;
```

* Results:

| OP | project_id | user_id | task_id |
| ---| ---------- | ------- | -----   |
| +I | P  | u1  | t1 |
| +I | P  | u2 | t1 |
| +I | P  | u1 | t2 |
| +I | P  | u2 | t2 |
| +I | P  | u1 | t3 |
| +I | P  | u2 | t3 |
| +I | Q  | u9 | t9 |


### Approach 2 — ROW_NUMBER top-1 dedup: UPDATING changelog, one row PER KEY.

The result is keyed by project_id (the PARTITION BY column), so each project holds exactly
ONE row. Every new task does not add a row -- it RETRACTS the old winner and emits the new one:

--   +I (P, t1)
--   -U (P, t1)  +U (P, t2)
--   -U (P, t2)  +U (P, t3)
--   +I (Q, t9)

* [File ./cc-flink/dml.rownumber_top1.sql](./cc-flink/dml.rownumber_top1.sql)
```sql
SELECT project_id, entity_id AS latest_task, event_ts
FROM (
  SELECT
    project_id,
    entity_id,
    event_ts,
    ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY event_ts DESC) AS rn
  FROM project_events
  WHERE event_type = 'TASK'
)
WHERE rn = 1;
```


Watch the "op" column in the Confluent Cloud Flink workspace to see the  -U / +U retract+update pairs. This is mutually exclusive with "keep many pairs per project": top-1 dedup is defined to keep one.

* Results:

| OP | project_id | latest_task | event_ts |
| ---| ---------- | ------- | -----   |
| +I | P          | t1      | 2026-01-01 10:00:05.000|
| +I | Q          | t9      | 2026-01-01 10:00:08.000 |
| +U | P          | t2      | 2026-01-01 10:00:15.000 |
| +U | P          | t3      | 2026-01-01 10:00:20.000


### Approach 3: 

* [File ./cc-flink/dml.cartesian_join.sql](./cc-flink/dml.match_recognize.sql)

```sql
SELECT *
FROM project_events
MATCH_RECOGNIZE (
  PARTITION BY project_id
  ORDER BY event_ts                 -- must order by the event-time attribute, ascending
  MEASURES
    U.entity_id           AS user_id,
    TEND.entity_id        AS task_id,            -- the task this match reports
    FIRST(TMID.entity_id) AS folded_first_task,  -- earlier task folded in (NULL if none)
    TEND.event_ts         AS paired_at
  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW
  PATTERN (U TMID* TEND) 
  DEFINE
    U    AS U.event_type    = 'USER',
    TMID AS TMID.event_type = 'TASK',
    TEND AS TEND.event_type = 'TASK'
) AS m;
```

Flink forbids a greedy quantifier as the final pattern element. PATTERN (U T+) ended on greedy T+.

### Why not update

That comes from the `ROW_NUMBER` top-1 / `GROUP BY` shape, which is **keyed by the partition column** (`project_id`). One row survives per key, so a newer winner **retracts** the old one (`-U` then `+U`). You cannot simultaneously want "keep many pairs per project" and "a new pair updates the old one" — those are mutually exclusive, and that tension is the real source of the confusion.

## Key Concepts

| Concept | Description |
|---------|-------------|
| Keyed changelog | `GROUP BY` / `ROW_NUMBER` top-N results are keyed by the grouping/partition column; that key decides INSERT vs UPDATE |
| `ONE ROW PER MATCH` | The only `MATCH_RECOGNIZE` output mode in Flink SQL; multi-event matches collapse to one row driven by `FIRST`/`LAST` measures |
| `AFTER MATCH SKIP PAST LAST ROW` | Non-overlapping matches: resume scanning after the last matched row |
| Regular join state | Non-windowed/non-temporal joins retain both sides indefinitely — bound with interval/temporal joins or state TTL |

## Layout

```
cc-flink/   Confluent Cloud Flink (deploy tooling + manifest)
  ddl.project_events.sql         unified append stream (USER + TASK events)
  dml.insert_project_events.sql  the scenario as deterministic VALUES
  dml.match_recognize.sql        APPROACH 1 — CEP sequential pairing (append)
  dml.rownumber_top1.sql         APPROACH 2 — top-1 dedup (updating changelog)
  dml.cartesian_join.sql         APPROACH 3 — plain join (literal M:N, append)
  Makefile  deploy_manifest.json
oss/        local Apache Flink SQL client (docker-compose) — same 3 queries
  ddl.project_events.sql         Kafka-backed source on the local broker
  dml.*.sql                      identical queries; see oss/README.md
  tests/insert_project_events.sql
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
1. Access to the [flink-tools-for-agents](https://github.com/jbcodeforce/flink-tools-for-agents) project at the same level as flink-studies

## Run (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-ddl          # create project_events
make deploy-data         # insert the u1,t1,u2,t2,t3 scenario
make deploy-pipeline     # run the MATCH_RECOGNIZE pairing (approach 1)

make undeploy
make drop-tables
```

To compare behaviors, paste `dml.rownumber_top1.sql` and `dml.cartesian_join.sql` into the Flink workspace and **watch the `op` column** (`+I`, `-U`, `+U`) — that column is where the INSERT-vs-UPDATE distinction becomes visible.


### Troubleshooting: MATCH_RECOGNIZE returns no rows

Event-time CEP only emits a match once the **watermark passes the match's last row**. On Confluent Cloud two traps cause an empty result, and this demo is built to avoid both:

1. **Idle partitions stall the watermark → zero rows.** A default multi-partition topic leaves some partitions empty; the source watermark is the min across partitions, so it never advances. Fix: create the table with `DISTRIBUTED INTO 1 BUCKETS` (see `cc-flink/ddl.project_events.sql`). If the table already exists, `make drop-tables` and redeploy.
2. **No event after the last match → final row missing.** With `t3` the latest event, the watermark never passes `t3`, so `(P,u2,t3)` never finalizes. Fix: the trailing `FLUSH` events in `dml.insert_project_events.sql` advance the watermark past `t3` (and are filtered out of every query).

Also keep inserts in `event_ts` order — the 1s watermark drops rows that arrive more than a second late.

## Run locally (OSS Apache Flink)

No Confluent Cloud account needed — the same three queries run on a local Flink SQL client + Kafka broker via `../docker-compose.yaml`. See [`oss/README.md`](./oss/README.md).

## Recommendation (production)

- **Pair each task with the user current at the task's event time** → use a **temporal join** against a versioned "latest user per project" table (`FOR SYSTEM TIME AS OF t.event_ts`). This yields `(P,u2,t2)` and `(P,u2,t3)` as *separate* append rows (the per-task M:N result that `ONE ROW PER MATCH` cannot produce), with bounded, point-in-time-correct state. See `../rule-match-on-sensors` for the temporal-join pattern.
- **Detect ordered event sequences** → `MATCH_RECOGNIZE`.
- **Avoid a UDF** for this — none of these require one.

> Not yet run against a live cluster — SQL is validated for syntax/semantics only. Expected changelogs are documented in each `dml.*.sql` header.
