-- this is to mockup table created by CDC
CREATE TABLE provider_master (
  headers ROW < op STRING,  ts_ms TIMESTAMP(3),  transaction_id STRING >,

  afterData STRING,
  beforeData STRING,
  systemOfRecord ROW < sourceSystem STRING, sourceEntity STRING,
  sourcePublishedDate STRING,
  sourceCorrelationReference STRING,
  entityKey STRING >,
  changeSet ARRAY <
              ROW < name STRING,
                    changes ARRAY < ROW < action STRING,
                                          recordKeys ROW < providerNetworkId STRING >,
                                          srcPublishRef STRING
                                        >
                                  >
                  >
            >

) WITH (
  'changelog.mode' = 'append',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'json-registry'

);