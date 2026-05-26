---
title: Watermark
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, metadata, streaming]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Watermark

## Overview
A [[watermark]] defines the event-time progress in a Flink SQL stream. It tells the runtime when to consider event time advanced enough to process late events and emit window results.

## Watermark Definition
```sql
CREATE TABLE events (
    event_time TIMESTAMP_LTZ(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
);
```

The watermark is defined as `event_time - lag`, where lag is the maximum allowed delay for out-of-order events.

## Watermark Sources
- **From Kafka `$rowtime`**: Default on Confluent Cloud; `$rowtime` equals the Kafka message timestamp
- **From column**: Extract from the value using `METADATA FROM 'timestamp'`
- **From schema**: Avro Schema Registry `timestamp_type` annotations

## Late Events
Events arriving after the watermark has passed are [[watermark]] and can be handled by:
1. Increasing the watermark lag (trade-off with latency)
2. Using [[watermark]] for late-arriving data
3. Setting watermark to 0 for reference tables in [[enrichment-join]] (skip waiting)

## Modifying Watermarks
```sql
-- Change watermark lag
ALTER TABLE tbl MODIFY WATERMARK FOR $rowtime AS $rowtime - INTERVAL '1' SECOND;

-- Remove watermark
ALTER TABLE tbl DROP WATERMARK;

-- Set max watermark (for reference tables in enrichment joins)
ALTER TABLE tbl SET `$rowtime` = TO_TIMESTAMP('', 0);
```

## Key Concepts
- Watermarks are monotonically increasing (never decrease)
- Higher lag = more correct window results but more latency
- Lower lag = faster results but potentially incomplete windows
- The watermark determines when a window can be finalized

## Related
- [[watermark]] processing
- [[watermark]] semantics (tumble, slide, session)
- [[kafka-partitioning]] and Kafka offset processing
- [[primary-key]] implications for watermark storage
