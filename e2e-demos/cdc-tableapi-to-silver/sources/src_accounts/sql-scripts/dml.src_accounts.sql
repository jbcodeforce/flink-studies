-- Unpack Debezium envelope from raw_accounts into src_accounts.
-- Use before for DELETE, after otherwise; source.ts_ms for event time.
INSERT INTO src_accounts
SELECT
    COALESCE(IF(op = 'd', `before`.account_id, `after`.account_id), '') AS account_id,
    COALESCE(IF(op = 'd', `before`.account_name, `after`.account_name), '') AS account_name,
    COALESCE(IF(op = 'd', `before`.region, `after`.region), '') AS region,
    COALESCE(IF(op = 'd', `before`.created_at, `after`.created_at), '') AS created_at,
    op AS src_op,
    (op = 'd') AS is_deleted,
    TO_TIMESTAMP_LTZ(`source`.ts_ms, 3) AS src_timestamp
FROM raw_accounts
WHERE `source`.ts_ms IS NOT NULL;
