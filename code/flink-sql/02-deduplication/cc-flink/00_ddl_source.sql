-- SOURCE TABLE: append-only Kafka topic simulating a raw dimension feed.
-- Each INSERT represents a CDC-style event or re-emitted snapshot row.
-- Ties on updated_at are intentional — they trigger the rank-flip scenario
-- that produces Frankenstein rows in the buggy downstream aggregation.
CREATE TABLE IF NOT EXISTS dim_source_events (
    pk_col1    STRING NOT NULL,
    pk_col2    STRING NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    event_uuid STRING NOT NULL,       -- unique per event; used as tiebreaker in safe pattern
    column_a   STRING,
    column_b   STRING,
    column_c   STRING
) DISTRIBUTED BY HASH(pk_col1, pk_col2) INTO 4 BUCKETS
WITH (
    'changelog.mode'       = 'append',
    'scan.startup.mode'    = 'earliest-offset',
    'value.fields-include' = 'all',
    'value.format'         = 'json-registry',
    'key.format'           = 'json-registry'
);
