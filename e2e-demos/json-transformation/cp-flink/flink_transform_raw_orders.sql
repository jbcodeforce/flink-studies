
INSERT INTO `order-details` (OrderDetails, MovingHelpDetails)
SELECT
  ROW( -- Corresponds to the 'OrderDetails' column
    ARRAY[ -- Corresponds to the 'EquipmentRentalDetails' field, which is an array
      ROW( -- A single element in the 'EquipmentRentalDetails' array
        r.OrderId,                                    -- BIGINT (matches)
        r.Status,                                     -- STRING (matches)
        r.Equipment,                                  -- ARRAY<ROW<ModelCode STRING, Rate STRING>> (matches)
        CAST(r.TotalPaid AS DOUBLE),                 -- DECIMAL(10,2) -> DOUBLE conversion
        r.Type,                                       -- STRING (matches)
        r.Coverage,                                   -- STRING (matches) - corrected from empty string
        ROW(                                          -- Itinerary conversion TIMESTAMP -> STRING
          CAST(r.Itinerary.PickupDate AS STRING),    -- TIMESTAMP(3) -> STRING conversion
          CAST(r.Itinerary.DropoffDate AS STRING),   -- TIMESTAMP(3) -> STRING conversion
          r.Itinerary.PickupLocation,                 -- STRING (matches)
          r.Itinerary.DropoffLocation                 -- STRING (matches)
        ),
        r.OrderType,                                  -- STRING (matches)
        CAST(r.AssociatedContractId AS BIGINT)       -- STRING -> BIGINT conversion
      )
    ]
  ),
  NULL -- 'MovingHelpDetails' is set to NULL as it's not in the source data
FROM `raw-orders` AS r;
