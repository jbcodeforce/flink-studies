-- Enriched cart snapshot: product list + total price. Upsert keyed by cart_id.
CREATE TABLE IF NOT EXISTS integrated_cart (
    cart_id STRING NOT NULL,
    user_id STRING,
    cart_status STRING,
    cart_date DATE,
    total_price DECIMAL(10, 2),
    products ARRAY<
        ROW<
            product_id STRING,
            name STRING,
            price DECIMAL(10, 2),
            availability BOOLEAN,
            quantity INT
        >
    >,
    PRIMARY KEY (cart_id) NOT ENFORCED
) DISTRIBUTED BY HASH(cart_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'kafka.cleanup-policy' = 'delete',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
