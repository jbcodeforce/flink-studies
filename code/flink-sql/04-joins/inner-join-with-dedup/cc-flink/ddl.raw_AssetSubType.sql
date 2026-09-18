create table raw_AssetSubType (
    id string,
    name string,
    description string,
    ts_ltz timestamp_ltz(3),
    WATERMARK FOR ts_ltz AS ts_ltz - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED 
) DISTRIBUTED BY HASH(id) into 1 buckets WITH (
      'changelog.mode' = 'append',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all',
      'scan.startup.mode' = 'earliest-offset',
      'scan.bounded.mode' = 'unbounded'
);