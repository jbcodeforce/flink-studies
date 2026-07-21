-- Normalize multi-schema JSON (Confluent wire format on raw_value) into
-- the Avro-union account_events sink.
-- Wire format: magic (1 byte) + schema_id (4 bytes) + UTF-8 JSON body.
INSERT INTO account_events

with parsed as(
  SELECT contextInfo,
        eventDetail.connect_union_field_0 as deviseSwap,
        eventDetail.connect_union_field_1 as subscription,
        eventDetail.connect_union_field_2 as deviceClose,
  FROM `raw_account_events`
)
SELECT
   contextInfo.correlationId as correlationId,
  eventDetail,
  ROW(
        contextInfo.eventName,
        contextInfo.correlationId,
        contextInfo.sourceSystem
    ) as contextInfo,
    CASE contextInfo.eventName
        WHEN 'DeviceSwap' THEN ROW(
            ROW(
                deviseSwap.accountId,
                deviseSwap.deviceId
            ),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
        WHEN 'Subscription' THEN ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            ROW(
                subscription.accountId,
                subscription.status,
                subscription.planId
            ),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
        WHEN 'DeviceClose' THEN ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            ROW(
                deviceClose.accountId,
                deviceClose.reasonCode
            )
        )
    END as ed
FROM parsed;
