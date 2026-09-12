-- VECTOR 3: Flink Retract Window Frankenstein
-- Requires: running Flink job (06_dml_buggy.sql) + an append-only source topic.
--
-- MECHANISM:
--   The source is append-only. The ROW_NUMBER() operator therefore generates
--   retract (-U) messages internally whenever a newly arrived event outranks the
--   current rn=1 row for a given PK.
--
--   The downstream GROUP BY sid + MAX() is a retract aggregation. When it receives:
--     +I  [sid=H1, col_a=X, col_b=P]   ← row A becomes rn=1
--     -U  [sid=H1, col_a=X, col_b=P]   ← row A retracted (tie arrived)
--     +U  [sid=H1, col_a=Y, col_b=Q]   ← row B is new rn=1
--
--   Between the -U and the +U the MAX() accumulator holds the partially retracted
--   state. With a timestamp tie, the ROW_NUMBER operator may NOT emit a -U before
--   the +U for the incoming tied row — it may emit two +I events (both ranked 1
--   transiently), causing the MAX() to accumulate BOTH rows simultaneously.
--
--   By choosing values where col_a is highest in row A and col_b is highest in row B,
--   the MAX() output blends columns from two different source rows:
--     MAX(col_a) = val from row A
--     MAX(col_b) = val from row B
--   → The sink record never existed in any source event. FRANKENSTEIN.
--
-- HOW TO OBSERVE:
--   1. Start 06_dml_buggy.sql (continuous INSERT into dim_output_buggy).
--   2. Run the INSERT statements below to seed the source topic.
--   3. Immediately run 08_verify.sql before log compaction collapses the topic.
--   4. The NOT EXISTS check returns rows proving the blend.

-- ---------------------------------------------------------------------------
-- SEQUENCE A: entity_1 — tied timestamps, both columns split across rows
-- ---------------------------------------------------------------------------

-- Event A1: arrives first, becomes rn=1 immediately.
INSERT INTO dim_source_events VALUES
    ('entity_1', 'region_A',
     TIMESTAMP '2024-06-01 10:00:00.000',
     'uuid-aaa-001',
     'zzz_ALPHA',    -- column_a: HIGH → will WIN MAX across the two rows
     'aaa_FIRST',    -- column_b: LOW  → will LOSE MAX
     'cat_X'),

-- Event A2: same PK, SAME updated_at → timestamp tie.
-- ROW_NUMBER must now decide which row holds rn=1. During the transition
-- both rows transiently pass through the WHERE rn=1 filter, feeding MAX().
    ('entity_1', 'region_A',
     TIMESTAMP '2024-06-01 10:00:00.000',   -- SAME timestamp → tie
     'uuid-bbb-002',
     'aaa_BETA',     -- column_a: LOW  → will LOSE MAX
     'zzz_SECOND',   -- column_b: HIGH → will WIN MAX
     'cat_Y'),

-- Transient buggy MAX() output for entity_1:
--   column_a = MAX('zzz_ALPHA', 'aaa_BETA')   = 'zzz_ALPHA'  ← from event A1
--   column_b = MAX('aaa_FIRST', 'zzz_SECOND') = 'zzz_SECOND' ← from event A2
--   column_c = MAX('cat_X', 'cat_Y')          = 'cat_Y'      ← from event A2
-- column_a and column_b came from DIFFERENT source rows → FRANKENSTEIN.

-- ---------------------------------------------------------------------------
-- SEQUENCE B: entity_2 — higher timestamp arrives after initial rn=1 is set
-- ---------------------------------------------------------------------------

-- Event B1: lower timestamp, becomes rn=1 initially.
    ('entity_2', 'region_B',
     TIMESTAMP '2024-06-01 09:00:00.000',   -- OLDER timestamp
     'uuid-ccc-003',
     'zzz_GAMMA',    -- column_a: HIGH → will WIN MAX during retract window
     'aaa_THIRD',    -- column_b: LOW
     'cat_M'),

-- Event B2: NEWER timestamp — outranks B1, triggers a rank flip.
-- The ROW_NUMBER operator retracts B1 and promotes B2 to rn=1.
-- During the retract/re-insert cycle, MAX() briefly holds BOTH rows.
    ('entity_2', 'region_B',
     TIMESTAMP '2024-06-01 11:00:00.000',   -- NEWER timestamp → displaces B1
     'uuid-ddd-004',
     'aaa_DELTA',    -- column_a: LOW  → will LOSE MAX during blend window
     'zzz_FOURTH',   -- column_b: HIGH → will WIN MAX during blend window
     'cat_N');

-- Transient buggy MAX() output for entity_2 during rank flip:
--   column_a = MAX('zzz_GAMMA', 'aaa_DELTA') = 'zzz_GAMMA'  ← from event B1 (older!)
--   column_b = MAX('aaa_THIRD', 'zzz_FOURTH') = 'zzz_FOURTH' ← from event B2
-- After retract is fully processed, column_a should settle to 'aaa_DELTA' (from B2),
-- but the Frankenstein state was already emitted to the sink Kafka topic.
