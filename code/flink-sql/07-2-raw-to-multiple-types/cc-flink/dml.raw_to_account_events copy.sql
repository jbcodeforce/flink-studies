-- Normalize multi-schema JSON (Confluent wire format on raw_value) into
-- the Avro-union account_events sink.
-- Wire format: magic (1 byte) + schema_id (4 bytes) + UTF-8 JSON body.
INSERT INTO account_events
WITH parsed AS (
    SELECT SUBSTRING(CAST(`val` AS STRING), 6) AS payload
    FROM raw_account_events
)
SELECT
    JSON_VALUE(payload, 'lax $.contextInfo.correlationId') as correlationId,
    ROW(
        JSON_VALUE(payload, 'lax $.contextInfo.eventName'),
        JSON_VALUE(payload, 'lax $.contextInfo.correlationId'),
        JSON_VALUE(payload, 'lax $.contextInfo.sourceSystem')
    ) as contextInfo,
    CASE JSON_VALUE(payload, 'lax $.contextInfo.eventName')
        WHEN 'DeviceSwap' THEN ROW(
            ROW(
                JSON_VALUE(payload, 'lax $.eventDetail.accountId'),
                JSON_VALUE(payload, 'lax $.eventDetail.deviceId')
            ),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
        WHEN 'Subscription' THEN ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            ROW(
                JSON_VALUE(payload, 'lax $.eventDetail.accountId'),
                JSON_VALUE(payload, 'lax $.eventDetail.status'),
                JSON_VALUE(payload, 'lax $.eventDetail.planId')
            ),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
        WHEN 'DeviceClose' THEN ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            ROW(
                JSON_VALUE(payload, 'lax $.eventDetail.accountId'),
                JSON_VALUE(payload, 'lax $.eventDetail.reasonCode')
            )
        )
    END as eventDetail
FROM parsed;