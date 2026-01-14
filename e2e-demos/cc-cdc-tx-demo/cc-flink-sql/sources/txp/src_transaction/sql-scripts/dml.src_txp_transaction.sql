STATEMENT SET
BEGIN
INSERT INTO
  src_txp_transaction
SELECT
  COALESCE(txn_id, 'NULL') AS txn_id,
  COALESCE(account_number, 'NULL') AS account_number,
  TO_TIMESTAMP(REGEXP_REPLACE(COALESCE(`timestamp`, '2000-01-01T00:00:00.000000Z'),'T|Z',' '), 'yyyy-MM-dd HH:mm:SSSSSS') AS `timestamp`,
  COALESCE(amount, 0) AS amount,
  COALESCE(currency, 'NULL') AS currency,
  COALESCE(merchant, 'NULL') AS merchant,
  COALESCE(location, 'NULL') AS location,
  COALESCE(status, 'NULL') AS status,
  COALESCE(transaction_type, 'NULL') AS transaction_type,
  `partition` AS src_partition,
  `offset` AS src_offset
FROM
  `card-tx.public.transactions`
WHERE
  status <> 'PENDING';
INSERT INTO
  src_txp_pending_transaction
SELECT
  COALESCE(txn_id, 'NULL') AS txn_id,
  COALESCE(account_number, 'NULL') AS account_number,
  TO_TIMESTAMP(REGEXP_REPLACE(COALESCE(`timestamp`, '2000-01-01T00:00:00.000000Z'),'T|Z',' '), 'yyyy-MM-dd HH:mm:SSSSSS') AS `timestamp`,
  COALESCE(amount, 0) AS amount,
  COALESCE(currency, 'NULL') AS currency,
  COALESCE(merchant, 'NULL') AS merchant,
  COALESCE(location, 'NULL') AS location,
  COALESCE(status, 'NULL') AS status,
  COALESCE(transaction_type, 'NULL') AS transaction_type,
  `partition` AS src_partition,
  `offset` AS src_offset
FROM
  `card-tx.public.transactions`
WHERE
  status = 'PENDING';
END;
