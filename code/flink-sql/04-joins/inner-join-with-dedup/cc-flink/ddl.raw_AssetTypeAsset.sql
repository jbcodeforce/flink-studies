create table raw_AssetTypeAsset (
    AssetId string,
    TypeId string,
    Version int,
    ts_ltz timestamp_ltz(3),
     WATERMARK FOR ts_ltz AS ts_ltz - INTERVAL '5' SECOND,
     PRIMARY KEY (AssetId) NOT ENFORCED 
) DISTRIBUTED BY HASH(AssetId) into 1 buckets WITH (
      'changelog.mode' = 'append',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all',
      'scan.startup.mode' = 'earliest-offset',
      'scan.bounded.mode' = 'unbounded'
);
