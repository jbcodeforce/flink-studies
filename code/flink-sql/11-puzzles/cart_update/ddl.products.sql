-- Product catalog (dimension). Upsert so later price/availability updates fan out via join.
CREATE TABLE IF NOT EXISTS products (
    product_id STRING NOT NULL,
    name STRING,
    description STRING,
    price DECIMAL(10, 2),
    availability BOOLEAN,
    PRIMARY KEY (product_id) NOT ENFORCED
) DISTRIBUTED BY HASH(product_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'kafka.cleanup-policy' = 'delete',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
