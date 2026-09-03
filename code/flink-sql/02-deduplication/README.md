# Deduplication Examples

## Basic


## Frankenstein Rows

### Goals

Prove (or disprove) that the dimension deduplication pattern below can
produce "Frankenstein rows" — output rows whose column values are silently blended
from different source rows, violating row integrity.

**Pattern under test**:

```sql
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY pk_col1, pk_col2 ORDER BY updated_at DESC) AS rn
  FROM source_table
  WHERE ...
),
final AS (
  SELECT
    MD5(CONCAT_WS(',', pk_col1, pk_col2)) AS sid,
    column_a, column_b, column_c
  FROM ranked
  WHERE rn = 1
)
SELECT sid, MAX(column_a), MAX(column_b), MAX(column_c)
FROM final
GROUP BY sid;
```

### Scope

Three distinct proof vectors are addressed:

| # | Vector | Risk Level |
|---|--------|-----------|
| 1 | `CONCAT_WS` separator collision — different PK values produce same raw string | Low (design flaw, not probabilistic) |
| 2 | `ORDER BY` timestamp tie — `rn=1` assignment is non-deterministic when two rows share the same `updated_at` | Medium (data-dependent) |
| 3 | Flink retract/upsert window — `MAX()` downstream observes overlapping retract+insert during a rank flip, blending columns from two source rows | High (streaming-specific, always possible with ties) |

### CONCAT_WS Separator Collision

**Intent**: Show that `MD5(CONCAT_WS(',', pk_col1, pk_col2))` can produce the same `sid` for two logically different PK combinations, causing two distinct entities to map to a single group where `MAX()` blends their attributes.

```sql
SELECT
    pk_col1,
    pk_col2,
    CONCAT_WS(',', pk_col1, pk_col2)      AS raw_concat,
    MD5(CONCAT_WS(',', pk_col1, pk_col2)) AS sid,
    MAX(column_a) AS column_a,   -- 'Z_val' originates from row 2 (entity 'a'/'b,c')
    MAX(column_b) AS column_b    -- 'P_val' originates from row 1 (entity 'a,b'/'c')
FROM (VALUES
    ('a,b', 'c',   'A_val', 'P_val'),
    ('a',   'b,c', 'Z_val', 'D_val')
) AS t(pk_col1, pk_col2, column_a, column_b)
GROUP BY MD5(CONCAT_WS(',', pk_col1, pk_col2))
```

**Trigger condition**: `pk_col1 = 'a,b'` and `pk_col2 = 'c'` produces the same `CONCAT_WS` string as `pk_col1 = 'a'` and `pk_col2 = 'b,c'` — both yield `'a,b,c'`.

**Expected Outcome**: A runnable SQL query that inserts two rows with different PK values but identical `sid`, then shows the `MAX()` output blends their `column_a` and `column_b` values.

**Fix**: use a separator that could not be in pk, or use a null-byte separator (CHR(0)) that cannot appear in printable string PK values.

### ORDER BY Timestamp Tie

**Intent**: Show that when two source rows for the same PK have identical `updated_at`, the `ROW_NUMBER()` assignment of `rn=1` is arbitrary and changes between executions, causing the deduplication to return different rows across runs.

**This is not a Frankenstein row** in the classic sense — it is a *consistency* problem: repeated queries over the same data may return different column values.

Running the following query multiple time, the assignment may differ
```sql
SELECT
    pk_col1,
    updated_at,
    column_a,
    column_b,
    ROW_NUMBER() OVER (
        PARTITION BY pk_col1
        ORDER BY updated_at DESC       -- TIE: both rows have identical updated_at
    ) AS rn
FROM (VALUES
    ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'state_A', 'attr_P'),
    ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'state_B', 'attr_Q')
) AS t(pk_col1, updated_at, column_a, column_b);
```

**Expected Outcome**: A static SQL test with two rows sharing the same PK and `updated_at`, showing that `WHERE rn = 1` can return either row depending on physical ordering.


Combine with the MAX() — even without a collision the non-determinism means the "deduped" row silently changes between runs.

```sql
SELECT
    MD5(pk_col1) AS sid,
    MAX(column_a) AS column_a,
    MAX(column_b) AS column_b
FROM (
    SELECT
        pk_col1,
        column_a,
        column_b,
        ROW_NUMBER() OVER (
            PARTITION BY pk_col1
            ORDER BY updated_at DESC
        ) AS rn
    FROM (VALUES
        ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'state_A', 'attr_P'),
        ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'state_B', 'attr_Q')
    ) AS t(pk_col1, updated_at, column_a, column_b)
)
WHERE rn = 1
GROUP BY MD5(pk_col1);
```

Because of the tie, during the retract/re-insert cycle BOTH rows pass rn=1 at the same time, and MAX() picks 'state_B' (higher) and 'attr_Q' (higher) independently. A blend that may not represent either source row's intent.

**FIX:** add a unique event_uuid as the final ORDER BY key. This makes rn=1 assignment deterministic regardless of timestamp ties.
```sql
SELECT
    pk_col1,
    updated_at,
    event_uuid,
    column_a,
    column_b,
    ROW_NUMBER() OVER (
        PARTITION BY pk_col1
        ORDER BY updated_at DESC, event_uuid ASC   -- unique secondary key → always stable
    ) AS rn
FROM (VALUES
    ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'uuid-0001', 'state_A', 'attr_P'),
    ('entity_1', TIMESTAMP '2024-06-01 10:00:00.000', 'uuid-0002', 'state_B', 'attr_Q')
) AS t(pk_col1, updated_at, event_uuid, column_a, column_b);
```

### Flink Retract Window

**Intent**: Show that in Flink streaming SQL, when two rows for the same PK arrive with the same `updated_at` (a tie), the `ROW_NUMBER()` operator emits a retract message for the currently ranked row and promotes the new row. During the brief window between the retract of the old `rn=1` row and the commit of the new `rn=1` row, the downstream `GROUP BY sid + MAX()` aggregation observes both rows simultaneously, computing `MAX()` across two logically incompatible source rows.

**Why `WHERE rn = 1` does not fully protect you in streaming**:
- In batch: `WHERE rn = 1` produces a single final row per PK.
- In streaming (Flink): the `ROW_NUMBER()` operator emits changelog events. A rank flip caused by a tie or a late-arriving row produces:
  1. A retract (`-U`) for the old `rn=1` row
  2. An insert (`+U`) for the new `rn=1` row

These two events may not be processed atomically by the downstream aggregation.

**Expected Outcome**:
- A Flink SQL script that creates a Kafka source topic, inserts a controlled sequence of events including a timestamp tie, and reads from the downstream aggregation sink
  to show a transient state where `MAX(column_a)` reflects one source row and `MAX(column_b)` reflects a different source row.