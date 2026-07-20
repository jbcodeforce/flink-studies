-- Append-only account lifecycle envelope (topic: account_events).
-- Same Avro-union sink shape as 07-1-multiple-event-types.
-- value.eventDetail is an Avro union of DeviceSwapDetail | SubscriptionDetail | DeviceCloseDetail.
-- Flink maps the union as a ROW with one non-null branch per event.
CREATE TABLE IF NOT EXISTS account_events (
    correlationId STRING,
    contextInfo ROW<
        eventName STRING,
        correlationId STRING,
        sourceSystem STRING
    >,
    eventDetail ROW<
        DeviceSwapDetail ROW<accountId STRING, deviceId STRING>,
        SubscriptionDetail ROW<accountId STRING, status STRING, planId STRING>,
        DeviceCloseDetail ROW<accountId STRING, reasonCode STRING>
    >,
    PRIMARY KEY (correlationId) NOT ENFORCED
) DISTRIBUTED BY (correlationId) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
);
