-- Query to extract equipment total paid and create EquipmentRentalDetails from raw_orders
insert into order_details
SELECT
    OrderId,
        ARRAY[
            ROW(
                OrderId,
                Status,
                Equipment,
                CAST(TotalPaid AS DECIMAL(10,2)),
                Type,
                Coverage,
                ROW(
                    CAST(Itinerary.PickupDate AS TIMESTAMP(3)),
                    CAST(Itinerary.DropoffDate AS TIMESTAMP(3)),
                    Itinerary.PickupLocation,
                    Itinerary.DropoffLocation
                ),
                OrderType,
                CAST(AssociatedContractId AS BIGINT)
            )
        ] as EquipmentRentalDetails,
   ARRAY[CAST(NULL AS ROW(
      job_id BIGINT,
      job_type STRING,
      job_status STRING,
      rate_service_provider STRING,
      total_paid DECIMAL(10,2),
      job_date_start STRING,
      job_completed_date STRING,
      job_entered_date STRING,
      job_last_modified_date STRING,
      service_provider_name STRING
    ))]  as MovingHelpDetails
FROM raw_orders
