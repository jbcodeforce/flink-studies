-- Validation variant: same filter, window, bucket, and LISTAGG as the production pipeline,
-- but the UDF is replaced by a deterministic expression so the job runs without LeadToBulkDev.
-- Use this to verify window boundaries, bucketing, and aggregation behavior.
--
-- Replace source and sink table names with your test tables (e.g. lead_test, lead_bulk_test).
-- Here we use CAST(`val` AS STRING) as the per-row "payload" so the bulk output is the concatenation
-- of filtered lead values in each (window, bucket). For a more NDJSON-like test, you could use
-- CONCAT(CAST(`val` AS STRING), '\n') as udf_out.

INSERT INTO `your_catalog.your_database.lead_bulk_sink`
SELECT
    CAST(CONCAT('b', CAST(bucket AS STRING)) AS BYTES) AS `key`,
    CAST(bulk_val AS BYTES) AS `val`
FROM (
    SELECT
        window_start,
        window_end,
        bucket,
        LISTAGG(udf_out, '') AS bulk_val
    FROM (
        SELECT
            window_start,
            window_end,
            bucket,
            CAST(`val` AS STRING) AS udf_out
        FROM (
            SELECT
                window_start,
                window_end,
                `key`,
                `val`,
                MOD(ABS(HASH_CODE(CAST(`key` AS STRING))), 5) AS bucket
            FROM TABLE(
                TUMBLE(
                    TABLE `your_catalog.your_database.lead`,
                    DESCRIPTOR(`$rowtime`),
                    INTERVAL '1' SECOND
                )
            )
            WHERE NOT (
                COALESCE(JSON_VALUE(CAST(`val` AS STRING), '$.__op'), '') = 'd'
                OR COALESCE(JSON_VALUE(CAST(`val` AS STRING), '$.__deleted'), 'false') = 'true'
            )
        ) windowed
        WHERE udf_out IS NOT NULL
    ) with_udf
    GROUP BY window_start, window_end, bucket
) aggregated
WHERE bulk_val IS NOT NULL AND bulk_val <> '';
