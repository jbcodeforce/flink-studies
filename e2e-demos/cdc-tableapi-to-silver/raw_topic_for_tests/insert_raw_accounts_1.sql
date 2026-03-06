-- Test data for raw_accounts: REFRESH/INSERT/UPDATE/DELETE.
-- Expected dimension rows: acc_001 (Acme North Ltd, NORTH), acc_002 (deleted or is_deleted=true).
EXECUTE STATEMENT SET
BEGIN
-- Snapshot/read: acc_001
INSERT INTO raw_accounts VALUES (
    CAST('acc_001' AS VARBINARY(2147483647)),
    ROW(1704067200000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_001', 'Acme North', 'NORTH', '2024-01-01T10:00:00'),
    'r'
);
-- Insert: acc_002
INSERT INTO raw_accounts VALUES (
    CAST('acc_002' AS VARBINARY(2147483647)),
    ROW(1704153600000),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    ROW('acc_002', 'Acme South', 'SOUTH', '2024-01-02T10:00:00'),
    'c'
);
-- Update: acc_001 -> Acme North Ltd
INSERT INTO raw_accounts VALUES (
    CAST('acc_001' AS VARBINARY(2147483647)),
    ROW(1704240000000),
    ROW('acc_001', 'Acme North', 'NORTH', '2024-01-01T10:00:00'),
    ROW('acc_001', 'Acme North Ltd', 'NORTH', '2024-01-01T10:00:00'),
    'u'
);
-- Delete: acc_002
INSERT INTO raw_accounts VALUES (
    CAST('acc_002' AS VARBINARY(2147483647)),
    ROW(1704326400000),
    ROW('acc_002', 'Acme South', 'SOUTH', '2024-01-02T10:00:00'),
    CAST(NULL AS ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>),
    'd'
);
END;
