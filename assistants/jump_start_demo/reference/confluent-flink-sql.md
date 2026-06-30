# Confluent Cloud Flink SQL — critical rules

Apply these rules when writing or editing SQL under `cccloud/`.

## Never use

```sql
'connector' = 'kafka'
'topic' = 'my-topic'
'kafka.topic' = 'my-topic'
'bootstrap.servers' = '...'
```

Confluent Cloud Flink manages Kafka connectivity via catalog/database context.

## Always use

```sql
'key.format' = 'avro-registry',   -- or json-registry
'value.format' = 'avro-registry'
```

## Table definitions

- Key/distribution column **first** in schema
- `DISTRIBUTED BY (key_col) INTO N BUCKETS` for tables without PRIMARY KEY
- Or `PRIMARY KEY (...) NOT ENFORCED` for upsert/changelog sinks
- `WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND` on event-time columns

## Source table pattern

```sql
CREATE TABLE events (
  event_id STRING,
  event_time TIMESTAMP(3),
  payload STRING,
  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) DISTRIBUTED BY (event_id) INTO 4 BUCKETS
WITH (
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
);
```

## Destination (upsert) pattern

```sql
CREATE TABLE alerts (
  customer_id STRING,
  alert_time TIMESTAMP(3),
  risk_score DECIMAL(5, 2),
  PRIMARY KEY (customer_id, alert_time) NOT ENFORCED
) WITH (
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
);
```

## Window aggregation

```sql
INSERT INTO aggregates
SELECT
  key_column,
  window_end,
  COUNT(*) AS cnt
FROM TABLE(
  TUMBLE(TABLE source_table, DESCRIPTOR(event_time), INTERVAL '5' MINUTES)
)
GROUP BY key_column, window_start, window_end;
```

## File naming (for deploy manifest)

| Pattern | Manifest group |
|---------|----------------|
| `ddl.*.sql` | ddl |
| `dml.*.sql` (not insert/update) | pipeline |
| `insert_*.sql`, `dml.insert_*.sql` | data |
| `dml.update_*.sql`, `scenario.*.sql` | scenario |

See [deploy-manifest.md](deploy-manifest.md) for manifest generation.
