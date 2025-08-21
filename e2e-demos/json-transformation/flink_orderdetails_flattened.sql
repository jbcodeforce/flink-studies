-- Alternative approach: Flattened OrderDetails table for easier processing
-- This creates a simpler structure if you prefer to work with flattened data

-- Source table (same as before) to read the JSON
CREATE TABLE OrderDetails_Source (
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
  'topic' = 'order-details-raw',
  'properties.bootstrap.servers' = 'localhost:9092',
  'properties.group.id' = 'order-details-source-consumer',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true',
  'scan.startup.mode' = 'earliest-offset'
);

-- Flattened target table for processed order details
CREATE TABLE OrderDetails_Flattened (
  order_id BIGINT,
  order_status STRING,
  equipment_model_code STRING,
  equipment_rate STRING,
  total_paid DOUBLE,
  order_type STRING,
  coverage STRING,
  pickup_date STRING,
  dropoff_date STRING,
  pickup_location STRING,
  dropoff_location STRING,
  order_category STRING,
  associated_contract_id BIGINT,
  moving_help_details STRING,
  processed_time TIMESTAMP(3),
  PRIMARY KEY (order_id, equipment_model_code) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'order-details-processed',
  'properties.bootstrap.servers' = 'localhost:9092',
  'format' = 'json',
  'json.timestamp-format.standard' = 'ISO-8601'
);

-- INSERT statement to transform and flatten the nested JSON structure
INSERT INTO OrderDetails_Flattened
SELECT 
  rental_detail.OrderId as order_id,
  rental_detail.Status as order_status,
  equipment_item.ModelCode as equipment_model_code,
  equipment_item.Rate as equipment_rate,
  rental_detail.TotalPaid as total_paid,
  rental_detail.Type as order_type,
  rental_detail.Coverage as coverage,
  rental_detail.Itinerary.PickupDate as pickup_date,
  rental_detail.Itinerary.DropoffDate as dropoff_date,
  rental_detail.Itinerary.PickupLocation as pickup_location,
  rental_detail.Itinerary.DropoffLocation as dropoff_location,
  rental_detail.OrderType as order_category,
  rental_detail.AssociatedContractId as associated_contract_id,
  MovingHelpDetails as moving_help_details,
  CURRENT_TIMESTAMP as processed_time
FROM OrderDetails_Source
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(rental_detail)
CROSS JOIN UNNEST(rental_detail.Equipment) AS e(equipment_item);

-- For use with shift_left CLI, you might create this as a pipeline:
-- 1. Create the source table (DDL)
-- 2. Create the target table (DDL) 
-- 3. Use the INSERT statement as your DML

-- Example usage with shift_left CLI:
-- shift_left table init order_details_source /path/to/pipeline
-- shift_left table init order_details_flattened /path/to/pipeline
-- shift_left pipeline deploy /path/to/inventory.json --table-name order_details_flattened