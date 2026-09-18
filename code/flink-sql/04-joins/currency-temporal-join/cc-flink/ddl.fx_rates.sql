-- FX rates reference table — versioned for FOR SYSTEM_TIME AS OF temporal joins.
--
-- Versioned table requirements on Confluent Cloud Flink:
--   1. PRIMARY KEY on the dimension columns only: (from_currency, to_currency).
--      Flink uses this to identify "which thing" the version belongs to.
--   2. changelog.mode = 'append' — every INSERT is a new immutable row; no row is
--      ever overwritten. This preserves the full rate history in the topic, which
--      is what the temporal join reads when resolving the version at trade_ts.
--   3. Confluent Cloud uses the Kafka message timestamp ($rowtime) as the implicit
--      rowtime for temporal joins — no WATERMARK clause is needed or allowed on
--      append tables used as temporal dimension tables.
--
-- Why append and NOT upsert:
--   With upsert mode the Kafka topic (and Flink's versioned store) keeps only the
--   latest row per key — previous rate versions are lost and the temporal join
--   always returns the current rate, not the historical one. Use append so every
--   tick is retained as a distinct row in the topic.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy         = compact    retain the latest value per key — combined
--                                       with append mode this retains all rows since
--                                       each (from,to,valid_from) triple is unique
--   kafka.retention.time   = 0          infinite retention; old versions must never expire
--   min.compaction.lag.ms  = 3600000    1 h grace before compactor runs
--
-- Cardinality: ~200 ISO-4217 pairs × ticks every few seconds ≈ 10 k msg/s peak.
-- State on the dimension side is bounded — Confluent Cloud Flink holds only the
-- snapshot required by the current probe-side watermark.

CREATE TABLE IF NOT EXISTS fx_rates (
    from_currency  STRING            NOT NULL,
    to_currency    STRING            NOT NULL,
    valid_from     TIMESTAMP_LTZ(3)  NOT NULL,  -- business time: when this rate became effective
    rate           DECIMAL(18, 8)    NOT NULL,
    source         STRING,
    PRIMARY KEY (from_currency, to_currency) NOT ENFORCED,
    WATERMARK FOR valid_from AS valid_from - INTERVAL '1' MINUTES
) DISTRIBUTED BY HASH(from_currency, to_currency) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'append',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
