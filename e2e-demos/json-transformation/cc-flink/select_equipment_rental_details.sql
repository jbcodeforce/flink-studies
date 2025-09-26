-- Select query to preview equipment rental details extraction from raw_orders
SELECT 
    OrderId,
    Status,
    Equipment,
    TotalPaid,
    Type,
    Coverage,
    Itinerary.PickupDate,
    Itinerary.DropoffDate,
    Itinerary.PickupLocation,
    Itinerary.DropoffLocation,
    OrderType,
    AssociatedContractId,
    -- Transformed structure for EquipmentRentalDetails
    ROW(
        OrderId,
        Status,
        Equipment,
        CAST(TotalPaid AS DOUBLE) as TotalPaid,
        Type,
        Coverage,
        ROW(
            CAST(Itinerary.PickupDate AS STRING) as PickupDate,
            CAST(Itinerary.DropoffDate AS STRING) as DropoffDate,
            Itinerary.PickupLocation,
            Itinerary.DropoffLocation
        ) as Itinerary,
        OrderType,
        CAST(AssociatedContractId AS BIGINT) as AssociatedContractId
    ) as EquipmentRentalDetail
FROM raw_orders
WHERE Equipment IS NOT NULL 
  AND CARDINALITY(Equipment) > 0
  AND TotalPaid > 0;

