-- SAFE SINK: output table for the corrected direct-projection dedup pattern.
-- Identical schema to the buggy sink — the difference is in the DML only.
CREATE TABLE IF NOT EXISTS dim_output_safe (
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
