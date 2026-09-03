-- BUGGY CONTINUOUS QUERY: the pattern under scrutiny.
--
-- The outer GROUP BY sid + MAX() is the root cause of Frankenstein blending:
--   - When sid is unique after WHERE rn = 1, the MAX() is redundant in batch.
--   - In Flink streaming it is UNSAFE: the MAX() aggregation processes retract
--     and re-insert events as ordinary group accumulations, blending columns from
--     two source rows during the rank-flip transition window.
--
-- Run this job FIRST, then seed events via 05_proof_v3_retract_frankenstein.sql.
-- Observe dim_output_buggy for Frankenstein states using 08_verify.sql.
INSERT INTO dim_output_buggy
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pk_col1, pk_col2
            ORDER BY updated_at DESC          -- no tiebreaker → non-deterministic on ties
        ) AS rn
    FROM dim_source_events
),
final AS (
    SELECT
        MD5(CONCAT_WS(',', pk_col1, pk_col2)) AS sid,
        column_a,
        column_b,
        column_c
    FROM ranked
    WHERE rn = 1
)
SELECT
    sid,
    MAX(column_a) AS column_a,   -- UNSAFE: blends across concurrent retract/insert events
    MAX(column_b) AS column_b,
    MAX(column_c) AS column_c
FROM final
GROUP BY sid;
