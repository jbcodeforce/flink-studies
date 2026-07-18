-- Normalize plain JSON (raw_value) into the Avro-union account_events sink.
INSERT INTO account_events
WITH parsed AS (
    SELECT CAST(`raw_value` AS STRING) AS payload
    FROM raw_account_events
)
SELECT
    JSON_VALUE(payload, 'lax $.contextInfo.correlationId'),
    ROW(
        JSON_VALUE(payload, 'lax $.contextInfo.eventName'),
        JSON_VALUE(payload, 'lax $.contextInfo.correlationId'),
        JSON_VALUE(payload, 'lax $.contextInfo.sourceSystem')
    ),
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
    END
FROM parsed;
