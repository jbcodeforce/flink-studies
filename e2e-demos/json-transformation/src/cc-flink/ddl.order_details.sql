create table `order-details` (
   OrderId BIGINT NOT NULL PRIMARY KEY not enforced,
   EquipmentRentalDetails ARRAY<ROW<
      OrderId BIGINT,
      Status STRING,
      Equipment ARRAY<ROW<
        ModelCode STRING,
        Rate STRING
      >>,
      TotalPaid DECIMAL(10,2),
      Type STRING,
      Coverage STRING,
      Itinerary ROW<
        PickupDate TIMESTAMP(3),
        DropoffDate TIMESTAMP(3),
        PickupLocation STRING,
        DropoffLocation STRING
      >,
      OrderType STRING,
      AssociatedContractId BIGINT>>,
  MovingHelpDetails MULTISET<ROW<
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
  >>
  ) distributed by hash(OrderId) into 1 buckets WITH ( 
   'value.avro-registry.schema-context' = '.dev',
   'kafka.retention.time' = '0',
    'changelog.mode' = 'upsert',
   'scan.bounded.mode' = 'unbounded',
   'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all'
);