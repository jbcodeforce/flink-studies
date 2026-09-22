
CREATE TABLE IF NOT EXISTS price_list_by_window (
    GUID        STRING NOT NULL,             
    start_date  TIMESTAMP_LTZ(3),     -- business start: price list becomes active for its buyer class
    end_date    TIMESTAMP_LTZ(3),     -- business end: price list expires
    CURRENCY    STRING,               -- varchar(255) — ISO-4217 currency code
    PRIMARY KEY (GUID, start_date, end_date,CURRENCY) NOT ENFORCED
) DISTRIBUTED BY HASH(GUID, start_date, end_date,CURRENCY) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
