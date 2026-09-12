-- BUGGY SINK: output table for the GROUP BY sid + MAX() pattern.
-- Primary key declared → Flink writes with upsert semantics.
-- Frankenstein states appear as transient upsert messages at intermediate
-- Kafka offsets before log compaction collapses them to the "final" value.
CREATE TABLE IF NOT EXISTS dim_output_buggy (
    sid      STRING NOT NULL,
    column_a STRING,
    column_b STRING,
    column_c STRING,
    PRIMARY KEY (sid) NOT ENFORCED
) DISTRIBUTED BY HASH(sid) INTO 4 BUCKETS
WITH (
    'changelog.mode'       = 'upsert',
    'scan.startup.mode'    = 'earliest-offset',
    'value.fields-include' = 'all',
    'value.format'         = 'json-registry',
    'key.format'           = 'json-registry'
);
