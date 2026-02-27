

CREATE TABLE IF NOT EXISTS leads_raw (
    `key`  STRING,
    `val`  STRING,
    PRIMARY KEY (`key`) NOT ENFORCED
) WITH (
    'value.format' = 'json-registry',
    'key.format'   = 'raw',
    'scan.startup.mode' = 'earliest-offset'
);
