-- INSERT statements for order-simple table
-- Based on simple.json schema structure matching our validated sample data

-- Single record INSERT matching our sample_valid.json data
INSERT INTO `order-simple` (OrderDetails)
VALUES (
  12345,
  ROW(
    12345,                                          -- OrderId (BIGINT)
    'Active',                                       -- Status (STRING)
    ARRAY[                                          -- Equipment (ARRAY<ROW<...>>)
      ROW('TRK001', '45.99'),                      -- Equipment item 1
      ROW('TRL002', '25.50')                       -- Equipment item 2
    ],
    71.49                                           -- TotalPaid (DOUBLE)
  )
);

-- Additional sample records for testing
INSERT INTO `order-simple` (OrderDetails)
VALUES 
  -- Record 1: Active rental with multiple equipment
  (ROW(
    98765,
    'Active',
    ARRAY[
      ROW('TRUCK_16FT', '39.95'),
      ROW('DOLLY_FURN', '9.95'),
      ROW('BLANKETS', '12.95')
    ],
    185.75
  )),
  
  -- Record 2: Completed order with single equipment  
  (ROW(
    54321,
    'Completed',
    ARRAY[ROW('TRUCK_26FT', '49.95')],
    267.50
  )),
  
  -- Record 3: Return status with trailer
  (ROW(
    11111,
    'Return',
    ARRAY[
      ROW('TRAILER_CARGO', '19.95'),
      ROW('STRAPS', '5.95')
    ],
    89.90
  )),
  
  -- Record 4: Pending order
  (ROW(
    22222,
    'Pending',
    ARRAY[ROW('TRUCK_10FT', '29.95')],
    125.00
  )),
  
  -- Record 5: Cancelled order
  (ROW(
    33333,
    'Cancelled',
    ARRAY[
      ROW('TRUCK_20FT', '44.95'),
      ROW('RAMP', '15.95')
    ],
    156.80
  ));

-- INSERT from transformation of raw_orders data (if raw_orders table exists)
-- This shows how to transform existing raw_orders data to the simple schema format
INSERT INTO `order-simple` (OrderDetails)
SELECT
  ROW(
    r.OrderId,                                      -- OrderId (BIGINT)
    r.Status,                                       -- Status (STRING) 
    r.Equipment,                                    -- Equipment (ARRAY) - already in correct format
    CAST(r.TotalPaid AS DOUBLE)                     -- TotalPaid (DOUBLE) - convert from DECIMAL
  ) AS OrderDetails
FROM raw_orders AS r
WHERE r.OrderId IS NOT NULL                         -- Basic validation
  AND r.Status IN ('Return', 'Active', 'Completed', 'Cancelled', 'Pending')
  AND CARDINALITY(r.Equipment) > 0;                 -- Ensure equipment array is not empty
