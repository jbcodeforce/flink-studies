{{ config(
    materialized = 'streaming_table',
    with= {
        'changelog.mode': 'append',
        'connector': 'confluent',
        'kafka.cleanup-policy': 'delete',
        'kafka.compaction.time': '0 ms',
        'kafka.max-message-size': '2097164 bytes',
        'kafka.retention.size': '0 bytes',
        'kafka.retention.time': '0 ms',
        'scan.bounded.mode': 'unbounded',
        'scan.startup.mode': 'earliest-offset',
        'value.format': 'avro-registry'
    }
  )
}}

with src_hosts AS (
  SELECT
    *
  FROM
    {{ ref('src_hosts') }}
)
SELECT
  host_id,
  COALESCE(host_name, 'Anonymous') AS host_name,
  is_superhost,
  created_at,
  updated_at
FROM
  src_hosts