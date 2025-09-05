-- Flink SQL transformation from raw_orders to OrderDetails schema
-- Handles proper data type conversions and nested structure

INSERT INTO `order-details` (OrderDetails, MovingHelpDetails)
SELECT
  ROW( -- Create ROW type for OrderDetails column
    ARRAY[ -- EquipmentRentalDetails array
      ROW( -- Single element in the EquipmentRentalDetails array
        r.OrderId,                                                         -- OrderId BIGINT
        r.Status,                                                          -- Status STRING
        r.Equipment,                                                       -- Equipment ARRAY<ROW<ModelCode STRING, Rate STRING>>
        CAST(r.TotalPaid AS DOUBLE),                                      -- TotalPaid should be DOUBLE, not BIGINT
        r.Type,                                                           -- Type STRING
        r.Coverage,                                                       -- Coverage STRING
        r.Itinerary,
        r.OrderType,                                                      -- OrderType STRING
        CAST(r.AssociatedContractId AS BIGINT)                           -- AssociatedContractId STRING -> BIGINT
      )
    ]
  ) AS OrderDetails,
  ARRAY[] AS MovingHelpDetails
FROM `raw-orders` AS r;


