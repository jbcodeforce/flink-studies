create table raw_contract (
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
) with (
  'connector' = 'kafka',
  'topic' = 'raw_contract',
  'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9092'
)