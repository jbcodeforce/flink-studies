# Package morning cutoff (11:30) – Flink SQL demo

Created 03/03/2026

## Goals

A simple demonstration about to present keeping last event per key, and emit events when there is no event since x hours for a given key. The use case is around package delivery. The shipping package events are sent to the Kafka `package_events` topic. There is a `package_id` as unique key. The major other fields are `event_time`, `status` and `expected_delivery` time.

1. Emit output event only when `expected_delivery` changed. Keep a <k,v>.
2. In the morning, there will be a  **cutofftime at 11:30am**. By cutofftime, we either pass through every received events or, for any expected package that had no recent event, proactively publish an event with same expected delivery time but a new event time that will be the cutofftime.
3. **Compute ETA:** From `package_events` (with location fields `current_location`, `delivery_address`), maintain per-package ETA history and estimated time of arrival (2h window, risk, confidence) using a UDF and join.

## Approach

### 1- Keep last expected_delivery per package

* One solution is using the last record by <package_id, expected_ts>:

   ```sql
   SELECT package_id, event_ts, status, expected_ts, payload
   FROM (
   SELECT *,
      ROW_NUMBER() OVER (
         PARTITION BY package_id, expected_ts
         ORDER BY event_ts ASC
      ) AS row_num
   FROM package_events
   )
   WHERE row_num = 1
   ```

   The matching SQLs are:
   - **src DDL**: `sql-scripts/ddl.package_events.sql`
   - **sink DDL**: `sql-scripts/ddl.last_expected_ts_package_events.sql` (sink table).
   - **DML**: `sql-scripts/dml.package_events_on_expected_ts_change.sql` (deduplication by package_id, expected_ts).

* A second approach is to use LAG and OVER time_window. You can also treat “emit when changed” requirement as: emit when `expected_ts` is different from the previous row’s `expected_ts` (or there is no previous row):
   ```sql
   SELECT package_id, event_ts, status, expected_ts, payload
   FROM (
      SELECT *,
         LAG(expected_ts, 1) OVER (PARTITION BY package_id ORDER BY event_ts) AS prev_expected_ts
      FROM package_events
   )
   WHERE prev_expected_ts IS NULL OR expected_ts <> prev_expected_ts
   ```

   LAG is a window function to get access to data from a previous row. The second argument is the offset, or the number of rows back from the current row, to retrieve value from. The OVER close specifies the time window.

one row per “change” of expected_ts per package_id. This is the `dml.package_event_expected_ts_with_lag.sql`


### 2- Emit events at cutoff time

For the second use case, at cutoff time, for each expected package that had **no** event before cutoff and some time window size, emit one row with `event_type = 'proactive_no_event'` and `event_ts = cutoff_ts`.

Use a stream of cutoff timestamps (`cutoff_ts`). One record per cutoff (e.g. one per day at 11:30). In production an external scheduler or job publishes this; in tests the test data injects it. To keep the right semantic the table could be dropped once processed.

All th **event time** and watermarks so that “before 11:30” is well-defined and tests are deterministic.

```sql
insert into  enhanced_package_events 
with proactive_events as (
  SELECT
    e.package_id,
    c.cutoff_ts as event_ts,
    e.status,
    e.expected_ts,
    'proactive_no_event' as event_type,
    e.payload
  FROM package_events e
  left JOIN cutoff_triggers c
    ON  e.event_ts BETWEEN c.cutoff_ts - INTERVAL '24' HOUR AND c.cutoff_ts - INTERVAL '2' hour
),
dedup_proactive_events as (
 SELECT package_id, event_ts, status, expected_ts, event_type, payload
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY package_id
        ORDER BY event_ts DESC
      ) AS row_num
    FROM proactive_events
  )
  where row_num = 1
 )
select * from dedup_proactive_events
union all
select * from last_expected_ts_package_events

```

Output is a single stream (union of both paths) for downstream consumers.

### 3- Compute ETA

From **package_events** (with optional `current_location` and `delivery_address`), the third use case maintains **package_eta_history**: one row per `package_id` with an array of event info and ETA fields. A table function `estimate_delivery(current_location, delivery_address, event_ts)` must be registered in the Flink catalog; it returns a 2h estimation window and risk/confidence. The DML `dml.package_eta_history.sql` aggregates from `package_events` and calls this UDF via a LATERAL join. The DML `dml.compute_eta.sql` joins `package_events` and `package_eta_history` to produce an ETA-enriched stream. For a Python mock of the UDF, see [./eta_udf/](./eta_udf/).

Below is the results

![](./images/enhanced_package_events.png)

## Deployment

This demo currently supports:

- **[Confluent Cloud](cccloud/)** – Run with Confluent CLI scripts and optional Terraform in `cccloud/IaC/`.

Other deployment targets (oss-flink, cp-flink) are not yet provided; see root [e2e-demos README](../README.md) for the standard layout.

## Running the demonstration

### Confluent Cloud ([cccloud/](cccloud/))

1. Prerequisites: Confluent Cloud (Kafka, Flink compute pool) and `confluent` CLI.
2. **Manual (Flink Workspace UI):** Copy-paste DDL/DML from `sql-scripts/` and `tests/` in order; see [cccloud/README.md](cccloud/README.md) for the sequence.
3. **Automated (Confluent CLI):** From the `cccloud/` folder, set `FLINK_DATABASE`, `FLINK_COMPUTE_POOL`, `FLINK_ENVIRONMENT`, then run:
   - `./run_use_case_1.sh`
   - `./run_use_case_2.sh`
   - `./run_use_case_3.sh` (requires `estimate_delivery` UDF registered; run use case 1 first).

Full details, prerequisites, and optional Terraform: [cccloud/README.md](cccloud/README.md).