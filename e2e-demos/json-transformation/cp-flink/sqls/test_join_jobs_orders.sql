
insert into `order-details`(OrderId, EquipmentRentalDetails, MovingHelpDetails)
/*+ OPTIONS('properties.transaction.timeout.ms'='300000') */
SELECT
  o.OrderId,
  ARRAY[
    row(
      o.OrderId,
      o.Status,
      o.Equipment,
      o.TotalPaid,
      o.`Type`,
      o.Coverage,
      o.Itinerary,
      o.OrderType,
      CAST(o.AssociatedContractId as BIGINT)
    )
  ] as EquipmentRentalDetails,
  ARRAY[ 
      ROW(
        j.job_id, 
        j.job_type,
        j.job_status,
        j.rate_service_provider,
        j.total_paid,
        j.job_date_start,
       j.job_completed_date,
       j.job_entered_date,
      j.job_last_modified_date,
      j.service_provider_name)
    ] as MovingHelpDetails
from `raw-orders` o join `raw-jobs` j on j.order_id = o.OrderId;