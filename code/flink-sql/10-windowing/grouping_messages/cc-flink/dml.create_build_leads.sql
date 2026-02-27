insert into `bulk_leads`
with bucketed as (SELECT
                window_start,
                window_end,
                `key`,
                `val`,
                `$rowtime`,
                MOD(ABS(HASH_CODE(CAST(`key` AS STRING))), 5) AS bucket
            FROM TABLE(
                TUMBLE(
                    TABLE `leads_raw`,
                    DESCRIPTOR(`$rowtime`),
                    INTERVAL '1' SECOND
                )
            )
            WHERE COALESCE(JSON_VALUE(CAST(`val` AS STRING), '$.__op'), '') <> 'd'
    ),
aggregated as (
      select
           window_start, window_end, bucket, LISTAGG(val, '\n') as bulk_val
      from bucketed group by window_start, window_end, bucket
)
select 
    CONCAT('b', CAST(bucket as STRING)) as `key`,
    bulk_val as val
from aggregated