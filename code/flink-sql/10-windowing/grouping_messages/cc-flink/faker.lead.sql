-- Faker source table for lead-shaped rows. produce test data into the lead input topic on Confluent Cloud.

CREATE TABLE IF NOT EXISTS leads_faker (
    lead_id    STRING,
    tenant_id  STRING,
    name       STRING,
    __op       STRING,
    __deleted  STRING,
    event_ts   TIMESTAMP(3)
) WITH (
    'connector' = 'faker',
    'changelog.mode' = 'append',
    'rows-per-second' = '1000',
    'fields.lead_id.expression' = '#{numerify ''L-###''}',
    'fields.tenant_id.expression' = '#{numerify ''tenant-###''}',
    'fields.name.expression' = '#{Name.fullName}',
    'fields.__op.expression' = '#{Options.option '''',''c'',''c'',''d''}',
    'fields.event_ts.expression' = '#{date.past ''5'', ''SECONDS''}'
);
