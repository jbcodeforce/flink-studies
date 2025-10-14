CREATE TABLE payment_events (
  payment_id STRING,
  claim_id STRING,
  payment_amount DECIMAL(10, 2),
  payment_date TIMESTAMP(3),
  processor_id STRING,
  payment_method STRING,
  payment_status STRING,
  reference_number STRING,
  transaction_id STRING,
  notes STRING,
  created_by STRING,
  event_time AS CAST(payment_date AS TIMESTAMP(3)),
  WATERMARK FOR event_time AS event_time - INTERVAL '2' MINUTE
) WITH (
  'changelog.mode' = 'append',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all',
  'value.format' = 'json-registry',
  'value.fields-include' = 'all'
)