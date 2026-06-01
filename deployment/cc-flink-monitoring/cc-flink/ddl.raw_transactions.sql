CREATE TABLE IF NOT EXISTS raw_transactions (
  transaction_id STRING NOT NULL,
  user_id        STRING NOT NULL,
  amount         DECIMAL(12, 2) NOT NULL,
  ts             TIMESTAMP(3) NOT NULL,
  PRIMARY KEY (transaction_id) NOT ENFORCED
) DISTRIBUTED BY HASH(transaction_id) INTO 1 BUCKETS WITH (
  'changelog.mode' = 'append',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'scan.bounded.mode' = 'unbounded',
  'kafka.cleanup-policy' = 'delete',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
