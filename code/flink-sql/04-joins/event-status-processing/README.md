# Event Status Processing

Track CDC event status transitions — from `eventProcessed = false` to `eventProcessed = true` — using a self-join or aggregation on an `event_status` CDC topic.

> **Status**: early-stage demo. The DDL is defined; pipeline SQL is a work-in-progress.

## Problem

A CDC topic receives events with three relevant columns:

- `eventId` — unique identifier for the event
- `eventProcessed` — boolean that switches from `false` to `true` when the event is processed
- `eventTime` — event timestamp

The goal is to detect events that have been processed and join them back to the original unprocessed event to compute processing latency, or to build a materialised view of current event state.

## Key Concepts

| Concept | Description |
|---------|-------------|
| CDC source | `event_status` topic with upsert/changelog semantics |
| Self-join on `eventId` | Join the unprocessed event to its processed version when `eventProcessed` flips |
| State TTL | Use `STATE_TTL` hint to bound how long unprocessed events are held in state |

## Layout

```
cc-flink/   Confluent Cloud Flink SQL (DDL, deploy manifest)
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
2. Deployment credentials in `../../../tools/`

## Run (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-ddl   # create event_status table

make drop-tables
```

## Table Definition

```sql
CREATE TABLE event_status (
  eventId        STRING NOT NULL,
  eventProcessed BOOLEAN,
  eventTime      TIMESTAMP_LTZ(3),
  PRIMARY KEY (eventId) NOT ENFORCED
) WITH (
  'changelog.mode' = 'upsert',
  ...
);
```

See [`ddl.event_status.sql`](./cc-flink/ddl.event_status.sql) for the full definition.
