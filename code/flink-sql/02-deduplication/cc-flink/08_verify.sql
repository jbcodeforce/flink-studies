-- INTEGRITY CHECK: surface Frankenstein rows in the buggy sink.
--
-- A Frankenstein row is defined as: a sink record whose combination of
-- (column_a, column_b, column_c) cannot be traced to a single source event
-- for the same logical PK. In other words, no source row exists where ALL
-- three attribute values match simultaneously.
--
-- Run this immediately after seeding events (05_proof_v3_retract_frankenstein.sql),
-- before log compaction collapses intermediate Kafka offsets.

-- ---------------------------------------------------------------------------
-- Check 1: Frankenstein detection in the buggy sink
-- ---------------------------------------------------------------------------
-- Returns rows where the sink record cannot be matched back to any single
-- source event. Any result here proves a Frankenstein state.
SELECT
    o.sid,
    o.column_a,
    o.column_b,
    o.column_c,
    'FRANKENSTEIN' AS verdict
FROM dim_output_buggy AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_source_events AS s
    WHERE MD5(CONCAT_WS(',', s.pk_col1, s.pk_col2)) = o.sid
      AND s.column_a = o.column_a
      AND s.column_b = o.column_b
      AND s.column_c = o.column_c
);
-- Expected with buggy pattern: ≥1 row returned.
-- If 0 rows: log compaction already collapsed the intermediate states.
--   → Run Check 2 (bounded scan) to observe the raw Kafka offsets instead.

-- ---------------------------------------------------------------------------
-- Check 2: Bounded raw scan of the buggy sink topic (before compaction)
-- ---------------------------------------------------------------------------
-- Read all upsert messages written to the buggy sink topic at each offset.
-- Compare consecutive records for the same sid to observe the transient blend.
SELECT
    sid,
    column_a,
    column_b,
    column_c
FROM dim_output_buggy
/*+ OPTIONS('scan.bounded.mode' = 'latest-offset') */
ORDER BY sid;
-- Inspect the output for the same sid appearing with different (col_a, col_b, col_c)
-- combinations. A combination that does not match any source row is a Frankenstein.

-- ---------------------------------------------------------------------------
-- Check 3: Confirm the safe sink is always clean
-- ---------------------------------------------------------------------------
-- Should always return 0 rows. Any result here would indicate a bug in the fix.
SELECT
    o.sid,
    o.column_a,
    o.column_b,
    o.column_c,
    'UNEXPECTED_BLEND' AS verdict
FROM dim_output_safe AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_source_events AS s
    WHERE MD5(CONCAT_WS(',', s.pk_col1, s.pk_col2)) = o.sid
      AND s.column_a = o.column_a
      AND s.column_b = o.column_b
      AND s.column_c = o.column_c
);
-- Expected: 0 rows always.

-- ---------------------------------------------------------------------------
-- Check 4: Side-by-side comparison of buggy vs safe sinks
-- ---------------------------------------------------------------------------
SELECT
    COALESCE(b.sid, s.sid)         AS sid,
    b.column_a                     AS buggy_col_a,
    s.column_a                     AS safe_col_a,
    b.column_b                     AS buggy_col_b,
    s.column_b                     AS safe_col_b,
    b.column_c                     AS buggy_col_c,
    s.column_c                     AS safe_col_c,
    CASE
        WHEN b.column_a <> s.column_a OR b.column_b <> s.column_b OR b.column_c <> s.column_c
        THEN 'MISMATCH'
        ELSE 'OK'
    END AS status
FROM dim_output_buggy  AS b
FULL OUTER JOIN dim_output_safe AS s ON b.sid = s.sid;
-- MISMATCH rows confirm the buggy sink diverged from the safe ground truth.
