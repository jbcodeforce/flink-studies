-- Provider transformation with deduplication
INSERT INTO provider_dimension
with providers as (
  select 
    headers.transaction_id as transaction_id,      -- row referenced via column name
    JSON_VALUE(afterData, '$.providerId') AS provider_id,
    JSON_VALUE(afterData, '$.firstName') AS first_name,
    JSON_VALUE(afterData, '$.lastName') AS last_name,
    JSON_VALUE(afterData, '$.specialty') AS specialty,
    JSON_VALUE(afterData, '$.npi') AS npi_number,
    ROW(
        JSON_VALUE(afterData, '$.practiceName'),    --json value for a key
        ROW(
           JSON_VALUE(JSON_QUERY(afterData,'$.address'),'$.street'),  -- nested json.
           JSON_VALUE(JSON_QUERY(afterData,'$.address'),'$.city'),
           JSON_VALUE(JSON_QUERY(afterData,'$.address'),'$.state'),
           JSON_VALUE(JSON_QUERY(afterData,'$.address'),'$.zipCode')
        )
    ) AS primary_location,
   $rowtime AS ts_ms,
   cast(changeSet[1].changes[1].action as string) as action    -- navigate array to get the action
  from provider_master where  headers.op <> 'DELETE'  and changeSet is not null  -- filter out DELETE operations
),

 deduplicated_providers AS (
    SELECT 
       *, ts_ms
        -- Use ROW_NUMBER to identify duplicates
        ROW_NUMBER() OVER (
            PARTITION BY 
                provider_id,  -- Partition by provider ID
                npi_number -- and NPI number for additional uniqueness
            ORDER BY ts_ms ASC) AS row_num
    FROM providers  
)
SELECT
   *
FROM deduplicated_providers
-- Only keep the first record for each provider (row_num = 1)
WHERE row_num = 1 