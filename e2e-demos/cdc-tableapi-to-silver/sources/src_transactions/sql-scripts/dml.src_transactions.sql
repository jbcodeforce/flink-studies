-- Unpack Debezium envelope from raw_transactions into src_transactions.
INSERT INTO src_transactions
SELECT
    COALESCE(IF(op = 'd', `before`.txn_id, `after`.txn_id), '') AS txn_id,
    COALESCE(IF(op = 'd', `before`.account_id, `after`.account_id), '') AS account_id,
    COALESCE(IF(op = 'd', `before`.amount, `after`.amount), 0) AS amount,
    COALESCE(IF(op = 'd', `before`.currency, `after`.currency), '') AS currency,
    TO_TIMESTAMP_LTZ(`source`.ts_ms, 3) AS `timestamp`,
    COALESCE(IF(op = 'd', `before`.status, `after`.status), '') AS status
FROM raw_transactions
WHERE `source`.ts_ms IS NOT NULL;
