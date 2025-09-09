with relevant_records as (
-- demonstrate data filtering with CTE
select
  *,
  $rowtime as ts
  from qlik_cdc_output_table  where headers.operation <> 'REFRESH' and (not (data is null and beforeData is null))
),
extracted_data as (
select
  key,
  coalesce(if(headers.operation in ('DELETE'), beforeData.id, data.id), 'NULL') as customer_id,
  coalesce(if(headers.operation in ('DELETE'), beforeData.name, data.name), 'NULL') as name,
  coalesce(if(headers.operation in ('DELETE'), beforeData.email, data.email), 'NULL') as email,
  coalesce(if(headers.operation in ('DELETE'), beforeData.age, data.age), 99) as age,
  coalesce(if(headers.operation in ('DELETE'), beforeData.created_at, data.created_at), 'NULL') as rec_created_ts,
  coalesce(if(headers.operation in ('DELETE'), beforeData.updated_at, data.updated_at), 'NULL') as rec_updated_ts,
  headers.operation as operation,
  headers.changeSequence as changeSequence,
  to_timestamp(headers.`timestamp`, 'yyyy-MM-dd HH:mm:ss') as tx_ts,
  IF(headers.operation in ('DELETE'), 1,0) as delete_ind,
  ts
from relevant_records)
 -- deduplicate records with the same key, taking the last records
select -- last projection to reduce columns
  customer_id, 
  name, 
  email, 
  age, 
  to_timestamp(rec_created_ts, 'yyyy-MM-dd HH:mm:ss') as rec_created_ts,
  to_timestamp(rec_updated_ts, 'yyyy-MM-dd HH:mm:ss') as rec_updated_ts,
  operation, 
  changeSequence, 
  tx_ts, 
  delete_ind
 from (
  select *,  ROW_NUMBER() OVER (
          PARTITION BY customerid_d, operation, changeSequence
          ORDER
            BY ts DESC
        ) AS row_num from extracted_data
  ) where row_num = 1;