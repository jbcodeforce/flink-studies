CREATE TABLE IF NOT EXISTS user_monthly_totals (
  user_id      STRING NOT NULL,
  user_name    STRING NOT NULL,
  user_email   STRING NOT NULL,
  month_start  TIMESTAMP(3) NOT NULL,
  total_amount DECIMAL(18, 2) NOT NULL,
  PRIMARY KEY (user_id, month_start) NOT ENFORCED
) DISTRIBUTED BY HASH(user_id, month_start) INTO 1 BUCKETS WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'scan.bounded.mode' = 'unbounded',
  'kafka.cleanup-policy' = 'compact',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
