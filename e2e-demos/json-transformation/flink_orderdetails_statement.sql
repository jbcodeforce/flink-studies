
SELECT
  -- Extract order details from the nested structure
  equipment_rental.OrderId as order_id,
  equipment_rental.Status as order_status,
  equipment_rental.TotalPaid as total_paid,
  equipment_rental.Type as order_type,
  equipment_rental.Coverage as coverage,
  equipment_rental.Itinerary.PickupDate as pickup_date,
  equipment_rental.Itinerary.DropoffDate as dropoff_date,
  equipment_rental.Itinerary.PickupLocation as pickup_location,
  equipment_rental.Itinerary.DropoffLocation as dropoff_location,
  equipment_rental.OrderType as order_category,
  equipment_rental.AssociatedContractId as contract_id,

  -- Extract equipment details (unnest the equipment array)
  equipment_item.ModelCode as equipment_model,
  equipment_item.Rate as equipment_rate,
  MovingHelpDetails as moving_help,

  event_time
FROM OrderDetails
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(equipment_rental)
CROSS JOIN UNNEST(equipment_rental.Equipment) AS e(equipment_item);