-- Test data for raw_transactions: snapshot and insert (COMPLETED).
-- 50 transactions distributed across acc_001..acc_010 (5 per account).
-- key, source, before, after, op

INSERT INTO raw_transactions VALUES (
    CAST('txn_1' AS VARBINARY(2147483647)),
    ROW(1705312800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_1', 'acc_001', 100.00, 'USD', '2024-01-15T12:00:00', 'COMPLETED'),
    'r'
), (
    CAST('txn_2' AS VARBINARY(2147483647)),
    ROW(1705316400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_2', 'acc_001', 50.00, 'USD', '2024-01-15T13:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_3' AS VARBINARY(2147483647)),
    ROW(1705317000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_3', 'acc_001', 75.50, 'USD', '2024-01-15T14:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_4' AS VARBINARY(2147483647)),
    ROW(1705317600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_4', 'acc_001', 120.00, 'USD', '2024-01-15T15:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_5' AS VARBINARY(2147483647)),
    ROW(1705318200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_5', 'acc_001', 33.25, 'USD', '2024-01-15T16:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_6' AS VARBINARY(2147483647)),
    ROW(1705318800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_6', 'acc_002', 200.00, 'USD', '2024-01-15T17:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_7' AS VARBINARY(2147483647)),
    ROW(1705319400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_7', 'acc_002', 45.75, 'USD', '2024-01-15T18:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_8' AS VARBINARY(2147483647)),
    ROW(1705320000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_8', 'acc_002', 88.00, 'USD', '2024-01-15T19:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_9' AS VARBINARY(2147483647)),
    ROW(1705320600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_9', 'acc_002', 156.50, 'USD', '2024-01-15T20:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_10' AS VARBINARY(2147483647)),
    ROW(1705321200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_10', 'acc_002', 22.25, 'USD', '2024-01-15T21:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_11' AS VARBINARY(2147483647)),
    ROW(1705321800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_11', 'acc_003', 90.00, 'USD', '2024-01-15T22:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_12' AS VARBINARY(2147483647)),
    ROW(1705322400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_12', 'acc_003', 67.00, 'USD', '2024-01-15T23:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_13' AS VARBINARY(2147483647)),
    ROW(1705323000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_13', 'acc_003', 134.75, 'USD', '2024-01-16T00:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_14' AS VARBINARY(2147483647)),
    ROW(1705323600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_14', 'acc_003', 41.50, 'USD', '2024-01-16T01:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_15' AS VARBINARY(2147483647)),
    ROW(1705324200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_15', 'acc_003', 99.99, 'USD', '2024-01-16T02:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_16' AS VARBINARY(2147483647)),
    ROW(1705324800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_16', 'acc_004', 250.00, 'USD', '2024-01-16T03:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_17' AS VARBINARY(2147483647)),
    ROW(1705325400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_17', 'acc_004', 15.25, 'USD', '2024-01-16T04:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_18' AS VARBINARY(2147483647)),
    ROW(1705326000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_18', 'acc_004', 178.50, 'USD', '2024-01-16T05:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_19' AS VARBINARY(2147483647)),
    ROW(1705326600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_19', 'acc_004', 62.00, 'USD', '2024-01-16T06:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_20' AS VARBINARY(2147483647)),
    ROW(1705327200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_20', 'acc_004', 310.75, 'USD', '2024-01-16T07:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_21' AS VARBINARY(2147483647)),
    ROW(1705327800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_21', 'acc_005', 55.50, 'USD', '2024-01-16T08:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_22' AS VARBINARY(2147483647)),
    ROW(1705328400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_22', 'acc_005', 189.00, 'USD', '2024-01-16T09:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_23' AS VARBINARY(2147483647)),
    ROW(1705329000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_23', 'acc_005', 72.25, 'USD', '2024-01-16T10:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_24' AS VARBINARY(2147483647)),
    ROW(1705329600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_24', 'acc_005', 145.00, 'USD', '2024-01-16T11:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_25' AS VARBINARY(2147483647)),
    ROW(1705330200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_25', 'acc_005', 28.99, 'USD', '2024-01-16T12:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_26' AS VARBINARY(2147483647)),
    ROW(1705330800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_26', 'acc_006', 95.50, 'USD', '2024-01-16T13:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_27' AS VARBINARY(2147483647)),
    ROW(1705331400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_27', 'acc_006', 210.00, 'USD', '2024-01-16T14:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_28' AS VARBINARY(2147483647)),
    ROW(1705332000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_28', 'acc_006', 38.75, 'USD', '2024-01-16T15:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_29' AS VARBINARY(2147483647)),
    ROW(1705332600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_29', 'acc_006', 167.25, 'USD', '2024-01-16T16:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_30' AS VARBINARY(2147483647)),
    ROW(1705333200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_30', 'acc_006', 44.00, 'USD', '2024-01-16T17:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_31' AS VARBINARY(2147483647)),
    ROW(1705333800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_31', 'acc_007', 82.50, 'USD', '2024-01-16T18:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_32' AS VARBINARY(2147483647)),
    ROW(1705334400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_32', 'acc_007', 125.00, 'USD', '2024-01-16T19:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_33' AS VARBINARY(2147483647)),
    ROW(1705335000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_33', 'acc_007', 19.99, 'USD', '2024-01-16T20:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_34' AS VARBINARY(2147483647)),
    ROW(1705335600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_34', 'acc_007', 276.25, 'USD', '2024-01-16T21:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_35' AS VARBINARY(2147483647)),
    ROW(1705336200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_35', 'acc_007', 53.50, 'USD', '2024-01-16T22:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_36' AS VARBINARY(2147483647)),
    ROW(1705336800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_36', 'acc_008', 118.00, 'USD', '2024-01-16T23:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_37' AS VARBINARY(2147483647)),
    ROW(1705337400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_37', 'acc_008', 64.75, 'USD', '2024-01-17T00:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_38' AS VARBINARY(2147483647)),
    ROW(1705338000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_38', 'acc_008', 192.50, 'USD', '2024-01-17T01:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_39' AS VARBINARY(2147483647)),
    ROW(1705338600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_39', 'acc_008', 31.00, 'USD', '2024-01-17T02:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_40' AS VARBINARY(2147483647)),
    ROW(1705339200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_40', 'acc_008', 205.99, 'USD', '2024-01-17T03:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_41' AS VARBINARY(2147483647)),
    ROW(1705339800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_41', 'acc_009', 77.25, 'USD', '2024-01-17T04:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_42' AS VARBINARY(2147483647)),
    ROW(1705340400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_42', 'acc_009', 143.50, 'USD', '2024-01-17T05:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_43' AS VARBINARY(2147483647)),
    ROW(1705341000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_43', 'acc_009', 26.00, 'USD', '2024-01-17T06:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_44' AS VARBINARY(2147483647)),
    ROW(1705341600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_44', 'acc_009', 358.75, 'USD', '2024-01-17T07:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_45' AS VARBINARY(2147483647)),
    ROW(1705342200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_45', 'acc_009', 91.00, 'USD', '2024-01-17T08:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_46' AS VARBINARY(2147483647)),
    ROW(1705342800000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_46', 'acc_010', 132.50, 'USD', '2024-01-17T09:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_47' AS VARBINARY(2147483647)),
    ROW(1705343400000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_47', 'acc_010', 48.25, 'USD', '2024-01-17T10:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_48' AS VARBINARY(2147483647)),
    ROW(1705344000000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_48', 'acc_010', 224.00, 'USD', '2024-01-17T11:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_49' AS VARBINARY(2147483647)),
    ROW(1705344600000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_49', 'acc_010', 59.99, 'USD', '2024-01-17T12:00:00', 'COMPLETED'),
    'c'
), (
    CAST('txn_50' AS VARBINARY(2147483647)),
    ROW(1705345200000),
    CAST(NULL AS ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>),
    ROW('txn_50', 'acc_010', 185.50, 'USD', '2024-01-17T13:00:00', 'COMPLETED'),
    'c'
);

