-- Query to extract equipment total paid and create EquipmentRentalDetails from raw_orders
INSERT INTO OrderDetails (OrderId, OrderDetails)
SELECT 
    OrderId,
    ROW(
        ARRAY[
            ROW(
                OrderId,
                Status,
                Equipment,
                CAST(TotalPaid AS DOUBLE) as TotalPaid,
                Type,
                Coverage,
                ROW(
                    CAST(Itinerary.PickupDate AS STRING),
                    CAST(Itinerary.DropoffDate AS STRING),
                    Itinerary.PickupLocation,
                    Itinerary.DropoffLocation
                ) as Itinerary,
                OrderType,
                CAST(AssociatedContractId AS BIGINT)
            )
        ]
    ) as OrderDetails
FROM raw_orders
WHERE Equipment IS NOT NULL 
  AND CARDINALITY(Equipment) > 0
  AND TotalPaid > 0;
