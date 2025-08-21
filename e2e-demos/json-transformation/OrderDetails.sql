-- Flink SQL statement to create OrderDetails table that matches the JSON document structure
-- This DDL creates a table that can consume JSON messages with the nested OrderDetails structure

CREATE TABLE OrderDetails (
  OrderDetails ROW<
    EquipmentRentalDetails ARRAY<ROW<
      OrderId BIGINT,
      Status STRING,
      Equipment ARRAY<ROW<
        ModelCode STRING,
        Rate STRING
      >>,
      TotalPaid DOUBLE,
      Type STRING,
      Coverage STRING,
      Itinerary ROW<
        PickupDate STRING,
        DropoffDate STRING,
        PickupLocation STRING,
        DropoffLocation STRING
      >,
      OrderType STRING,
      AssociatedContractId BIGINT
    >>
  >,
  MovingHelpDetails STRING,
  -- Additional metadata fields for Kafka processing
  event_time AS PROCTIME() -- Processing time for stream processing
) WITH (
  'connector' = 'kafka',
  'topic' = 'order-details',  -- Replace with your actual topic name
  'properties.bootstrap.servers' = 'localhost:9092',  -- Replace with your Kafka brokers
  'properties.group.id' = 'order-details-consumer',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',  -- Handle missing fields gracefully
  'json.ignore-parse-errors' = 'true',     -- Continue processing on parse errors
  'scan.startup.mode' = 'earliest-offset'  -- Start from beginning of topic
);
