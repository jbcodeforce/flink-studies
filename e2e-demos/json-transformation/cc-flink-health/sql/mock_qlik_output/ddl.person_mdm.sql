CREATE TABLE person_mdm (
  headers ROW<
    op STRING,
    ts_ms BIGINT,
    transaction_id STRING
  >,
  `data` STRING,
  beforeData STRING,
  systemOfRecord ROW<
    sourceSystem STRING,
    sourceEntity STRING,
    sourcePublishedDate STRING,
    sourceCorrelationReference STRING,
    entityKey STRING
  >

)