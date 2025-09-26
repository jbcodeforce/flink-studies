insert into order_details(OrderId, EquipmentRentalDetails,MovingHelpDetails)
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
  ],
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
    ] 
from raw_orders o join raw_jobs j on j.order_id = o.OrderId