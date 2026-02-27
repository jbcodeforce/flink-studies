
CREATE TABLE IF NOT EXISTS bulk_leads (
    `key`  STRING,
    `val`  STRING,
    PRIMARY KEY (`key`) NOT ENFORCED
) DISTRIBUTED BY HASH(`key`) INTO 5 BUCKETS WITH (
    'value.format' = 'json-registry',
    'key.format'   = 'raw',
    'scan.startup.mode' = 'earliest-offset'
);
