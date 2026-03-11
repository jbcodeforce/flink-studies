-- Test data for raw_accounts: REFRESH/INSERT/UPDATE/DELETE.
-- Expected dimension rows: acc_001 (Acme North Ltd, NORTH), acc_002 (deleted or is_deleted=true), acc_003..acc_010.
-- key, source, before, after, op
INSERT INTO raw_accounts VALUES (
    CAST('acc_001' AS VARBINARY(2147483647)),
    ROW(1704067200000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_001', 'Acme North', 'NORTH', '2024-01-01T10:00:00'),
    'r'
),
-- Insert: acc_002
(   CAST('acc_002' AS VARBINARY(2147483647)),
    ROW(1704153600000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_002', 'Acme South', 'SOUTH', '2024-01-02T10:00:00'),
    'c'
),
-- Insert: acc_003
(   CAST('acc_003' AS VARBINARY(2147483647)),
    ROW(1704232800000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_003', 'Beta East', 'EAST', '2024-01-03T10:00:00'),
    'c'
),
-- Insert: acc_004
(   CAST('acc_004' AS VARBINARY(2147483647)),
    ROW(1704319200000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_004', 'Gamma West', 'WEST', '2024-01-04T10:00:00'),
    'c'
),
-- Insert: acc_005
(   CAST('acc_005' AS VARBINARY(2147483647)),
    ROW(1704405600000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_005', 'Delta Central', 'CENTRAL', '2024-01-05T10:00:00'),
    'c'
),
-- Insert: acc_006
(   CAST('acc_006' AS VARBINARY(2147483647)),
    ROW(1704492000000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_006', 'Epsilon Ltd', 'NORTH', '2024-01-06T10:00:00'),
    'c'
),
-- Insert: acc_007
(   CAST('acc_007' AS VARBINARY(2147483647)),
    ROW(1704578400000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_007', 'Zeta Corp', 'SOUTH', '2024-01-07T10:00:00'),
    'c'
),
-- Insert: acc_008
(   CAST('acc_008' AS VARBINARY(2147483647)),
    ROW(1704664800000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_008', 'Eta Industries', 'EAST', '2024-01-08T10:00:00'),
    'c'
),
-- Insert: acc_009
(   CAST('acc_009' AS VARBINARY(2147483647)),
    ROW(1704751200000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_009', 'Theta Group', 'WEST', '2024-01-09T10:00:00'),
    'c'
),
-- Insert: acc_010
(   CAST('acc_010' AS VARBINARY(2147483647)),
    ROW(1704837600000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_010', 'Iota Partners', 'CENTRAL', '2024-01-10T10:00:00'),
    'c'
), (
    CAST('acc_001' AS VARBINARY(2147483647)),
    ROW(1704240000000),
    ROW('acc_001', 'Acme North', 'NORTH', '2024-01-01T10:00:00'),
    ROW('acc_001', 'Acme North Ltd', 'NORTH', '2024-01-01T10:00:00'),
    'u'
),
(
    CAST('acc_002' AS VARBINARY(2147483647)),
    ROW(1704326400000),
    ROW('acc_002', 'Acme South', 'SOUTH', '2024-01-02T10:00:00'),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    'd'
);

