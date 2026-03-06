-- Test data for raw_transactions: snapshot and insert (COMPLETED).
-- Expected fact rows: txn_1 (acc_001, 100.00), txn_2 (acc_001, 50.00).
EXECUTE STATEMENT SET
BEGIN
-- Snapshot: txn_1
INSERT INTO raw_transactions VALUES (
    CAST('txn_1' AS VARBINARY(2147483647)),
    ROW(1705312800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_1', 'acc_001', 100.00, 'USD', '2024-01-15T12:00:00', 'COMPLETED'),
    'r'
);
-- Insert: txn_2
INSERT INTO raw_transactions VALUES (
    CAST('txn_2' AS VARBINARY(2147483647)),
    ROW(1705316400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_2', 'acc_001', 50.00, 'USD', '2024-01-15T13:00:00', 'COMPLETED'),
    'c'
);
END;
