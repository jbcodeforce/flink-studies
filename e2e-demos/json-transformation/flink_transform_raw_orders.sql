-- This script contains the DDL for the source and sink tables, and the transformation logic to populate the sink table.

-- DDL for the source table `RawOrders`
-- This table consumes raw order data from the 'raw-orders' Kafka topic.
-- The schema is derived from the JSON schema provided for raw orders.
CREATE TABLE RawOrders (
  OrderId BIGINT,
  Status STRING,
  Equipment ARRAY<ROW<
    ModelCode STRING,
    Rate STRING
  >>,
  TotalPaid DOUBLE,
  Type STRING,
  Coverage STRING, -- Simplified from a complex type in source schema
  Itinerary ROW<
    PickupDate STRING,
    DropoffDate STRING,
    PickupLocation STRING,
    DropoffLocation STRING
  >,
  OrderType STRING,
  AssociatedContractId BIGINT, -- Simplified from a complex type in source schema
  event_time AS PROCTIME()
) WITH (
  'connector' = 'kafka',
  'topic' = 'raw-orders',
  'properties.bootstrap.servers' = 'localhost:9092',
  'properties.group.id' = 'raw-orders-consumer',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true',
  'scan.startup.mode' = 'earliest-offset'
);

-- DDL for the sink table `OrderDetails`
-- This table stores the transformed order data in a nested JSON structure.
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
  event_time AS PROCTIME()
) WITH (
  'connector' = 'kafka',
  'topic' = 'order-details',
  'properties.bootstrap.servers' = 'localhost:9092',
  'properties.group.id' = 'order-details-consumer',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true',
  'scan.startup.mode' = 'earliest-offset'
);

-- Transformation and insertion logic
-- This statement reads from `RawOrders`, transforms the data into the nested `OrderDetails` structure,
-- and inserts it into the `OrderDetails` table.
INSERT INTO OrderDetails (OrderDetails, MovingHelpDetails)
SELECT
  ROW( -- Corresponds to the 'OrderDetails' column
    ARRAY[ -- Corresponds to the 'EquipmentRentalDetails' field, which is an array
      ROW( -- A single element in the 'EquipmentRentalDetails' array
        r.OrderId,
        r.Status,
        r.Equipment,
        r.TotalPaid,
        r.Type,
        CAST(r.Coverage AS STRING),
        r.Itinerary,
        r.OrderType,
        CAST(r.AssociatedContractId AS BIGINT)
      )
    ]
  ),
  NULL -- 'MovingHelpDetails' is set to NULL as it's not in the source data
FROM RawOrders AS r;
