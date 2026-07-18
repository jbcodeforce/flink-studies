-- Plain-JSON source (topic: raw_account_events).
-- value.format = raw; payload accessed via raw-value metadata for JSON parsing.
CREATE TABLE IF NOT EXISTS raw_account_events (
    val BYTES,
    `raw_value` BYTES METADATA FROM 'raw-value' VIRTUAL
) DISTRIBUTED INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.format' = 'raw',
    'value.format' = 'raw'
);
