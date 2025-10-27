create table `raw-orders` (
    OrderId BIGINT,
    Status STRING,
    Equipment ARRAY<ROW<ModelCode STRING, Rate STRING
      >>,
      TotalPaid DECIMAL(10,2),
      Type STRING,
      Coverage STRING,
      Itinerary ROW<
        PickupDate TIMESTAMP(3),
        DropoffDate TIMESTAMP(3),
        PickupLocation STRING,
        DropoffLocation STRING
      >,
      OrderType STRING,
      AssociatedContractId STRING
)distributed by hash(OrderId) into 1 buckets WITH (
    'key.avro-registry.schema-context' = '.dev',
   'value.avro-registry.schema-context' = '.dev',
   'kafka.retention.time' = '0',
    'changelog.mode' = 'append',
   'kafka.cleanup-policy'= 'compact',
   'scan.bounded.mode' = 'unbounded',
   'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all'
)