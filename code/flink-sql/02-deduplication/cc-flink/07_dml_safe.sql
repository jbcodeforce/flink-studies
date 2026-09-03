-- SAFE CONTINUOUS QUERY: corrected deduplication pattern.
--
-- Two fixes applied:
--
--   FIX 1 — Remove the outer GROUP BY sid + MAX().
--     It is semantically redundant (sid is unique after WHERE rn = 1) and
--     structurally unsafe in streaming (MAX blends concurrent retract/insert pairs).
--     The direct projection writes an upsert stream keyed on sid with no
--     aggregation operator in the pipeline → no blending is possible.
--
--   FIX 2 — Add event_uuid as a deterministic ORDER BY tiebreaker.
--     When two events share the same updated_at, event_uuid (unique per event)
--     makes the rank assignment stable across restarts and operator re-orderings.
--
INSERT INTO dim_output_safe
SELECT
    MD5(CONCAT_WS(',', pk_col1, pk_col2)) AS sid,
    column_a,
    column_b,
    column_c
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pk_col1, pk_col2
            ORDER BY updated_at DESC, event_uuid ASC   -- deterministic: event_uuid is unique
        ) AS rn
    FROM dim_source_events
)
WHERE rn = 1;
-- Flink writes this directly as an upsert stream keyed on sid.
-- No MAX() in the pipeline means no column blending is possible at any point.
