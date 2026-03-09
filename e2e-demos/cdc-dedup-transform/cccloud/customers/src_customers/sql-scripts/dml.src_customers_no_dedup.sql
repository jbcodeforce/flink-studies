insert into src_customers
with -- transformation of the data
extracted_data as (
select
  key,
  coalesce(if(headers.operation in ('DELETE'), beforeData.id, data.id), 'NULL') as customer_id,
  coalesce(if(headers.operation in ('DELETE'), beforeData.name, data.name), 'NULL') as name,
  coalesce(if(headers.operation in ('DELETE'), beforeData.email, data.email), 'NULL') as email,
  coalesce(if(headers.operation in ('DELETE'), beforeData.age, data.age), 199) as age,
  coalesce(if(headers.operation in ('DELETE'), beforeData.created_at, data.created_at), '2025-09-10T12:00:00.000') as rec_created_ts,
  coalesce(if(headers.operation in ('DELETE'), beforeData.updated_at, data.updated_at), '2025-09-10T12:00:00.000') as rec_updated_ts,
  headers.operation as rec_crud_text,
  headers.changeSequence as hdr_changeSequence,
  to_timestamp(headers.`timestamp`, 'yyyy-MM-dd''T''HH:mm:ss.SSS') as hdr_timestamp,
  coalesce(if(headers.operation in ('DELETE'), beforeData.group_id, data.group_id), 'NULL') as group_id
from qlik_cdc_output_table )
 -- deduplicate records with the same key, taking the last records
select -- last projection to reduce columns
  customer_id,
  MD5(CONCAT_WS('||', customer_id)) AS rec_pk_hash,
  name,
  email,
  age,
  to_timestamp(rec_created_ts, 'yyyy-MM-dd''T''HH:mm:ss.SSS') as rec_created_ts,
  to_timestamp(rec_updated_ts, 'yyyy-MM-dd''T''HH:mm:ss.SSS') as rec_updated_ts,
  rec_crud_text,
  hdr_changeSequence,
  hdr_timestamp,
  group_id
 from extracted_data;