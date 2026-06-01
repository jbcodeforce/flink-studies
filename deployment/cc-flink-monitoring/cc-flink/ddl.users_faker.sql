-- Bounded faker: 100 users for the monitoring demo (no Kafka topic).
CREATE TABLE IF NOT EXISTS users_faker (
  user_id   STRING,
  full_name STRING,
  email     STRING
) WITH (
  'connector' = 'faker',
  'number-of-rows' = '100',
  'rows-per-second' = '50',
  'fields.user_id.expression' = '#{regexify ''user_(0[1-9][0-9]|100)''}',
  'fields.full_name.expression' = '#{Name.fullName}',
  'fields.email.expression' = '#{Internet.emailAddress}'
);
