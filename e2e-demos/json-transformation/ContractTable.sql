CREATE TABLE ContractTable (
  OrderId BIGINT,
  Status STRING,
  Equipment ARRAY<ROW<ModelCode STRING,Rate STRING>>,
  TotalPaid DOUBLE,
  `Type` STRING,
  Coverage STRING, -- NULL values are often represented as a nullable type
  Itinerary ROW<
    PickupDate STRING,
    DropoffDate STRING,
    PickupLocation STRING,
    DropoffLocation STRING
  >,
  OrderType STRING,
  AssociatedContractId BIGINT -- Assuming the NULL value would be a nullable BIGINT
) WITH (
  'connector' = 'filesystem',
  'path' = '/path/to/your/json/file',
  'format' = 'json'
);