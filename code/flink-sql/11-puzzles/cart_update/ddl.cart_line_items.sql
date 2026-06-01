-- Normalized open-cart line items. Upsert PK (cart_id, product_id) for join with products.
CREATE TABLE IF NOT EXISTS cart_line_items (
    cart_id STRING NOT NULL,
    product_id STRING NOT NULL,
    quantity INT,
    cart_status STRING,
    cart_date DATE,
    user_id STRING,
    PRIMARY KEY (cart_id, product_id) NOT ENFORCED
) DISTRIBUTED BY HASH(cart_id, product_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'kafka.cleanup-policy' = 'delete',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
