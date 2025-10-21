INSERT INTO order_details
SELECT
    999999 as OrderId,  -- Using a dummy order ID
    ARRAY[CAST(NULL AS ROW(
      OrderId BIGINT,
      Status STRING,
      Equipment ARRAY<ROW(ModelCode STRING, Rate STRING)>,
      TotalPaid DECIMAL(10,2),
      Type STRING,
      Coverage STRING,
      Itinerary ROW(
        PickupDate TIMESTAMP(3),
        DropoffDate TIMESTAMP(3),
        PickupLocation STRING,
        DropoffLocation STRING
      ),
      OrderType STRING,
      AssociatedContractId BIGINT
    ))] as EquipmentRentalDetails,
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
    ))]  as MovingHelpDetails;
