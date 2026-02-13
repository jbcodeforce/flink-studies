# Compute time to arrival of shipment

A company shipping goods between warehouses to end-buyers wants to compute the estimated time arrival, or ETA, from the different shipment events received over the time of the travel.

At each intermediate locations, a shipment event is created and from there and previous shipment estimates, a new estimation is computed.

## Approach

The source table is ShipmentEvent. 

ETA is computed with a User Defined Function to take current time, location and target address. The second SQL table, `shipment_history`, holds per-shipment key (`shipment_id`), an array of event infos (`event_history`), and ETA-related fields. A second SQL statement fills `shipment_history` from `shipment_events` (GROUP BY shipment_id, ARRAY_AGG). A third statement joins `shipment_events` and `shipment_history` on `shipment_id` to compute ETA.

ETA fields in `shipment_history`: `ETA_2h_time_window_start`, `ETA_2h_time_window_end`, `ETA_day`, `shipment_status`, `previous_ETA_2h_time_window_start`, `previous_ETA_2h_time_window_end`, `risk_score`, `confidence`. These are computed in `dml.shipment_history.sql` using the UDF below.

## Environment

This demonstration runs on Confluent Cloud.

## UDF assumption

A **table function** `estimate_delivery(current_location STRING, delivery_address STRING, event_ts TIMESTAMP(3))` is assumed to exist. Given current location, target address, and latest event timestamp, it returns one row with the estimated time-to-deliver: columns `eta_window_start`, `eta_window_end`, `risk_score`, `confidence` (the 2h estimation window and risk/confidence). It is invoked once per shipment via a LATERAL join in `dml.shipment_history.sql`. Register this table function in the Flink catalog before running the DML. `previous_ETA_2h_*` fields are left for stateful logic (e.g. prior event's window). A Python mock for prototyping lives in `udf/` (see [udf/README.md](udf/README.md)).

## Shipment event structure

The shipment has the following structure (JSON Lines, one event per line):

| Field | Type | Description |
|-------|------|--------------|
| `shipment_id` | string | Unique shipment identifier |
| `package_id` | string | Reference to what is really shipped |
| `event_ts` | string (ISO-8601) | Event timestamp |
| `event_type` | string | e.g. `dispatched`, `in_transit`, `delivered` |
| `current_location` | string (optional) | Current location or facility code |
| `delivery_address` | string | Delivery address (destination) |

Example:

```json
{"shipment_id": "SHP001", "package_id": "PKG-123", "event_ts": "2025-01-30T10:00:00Z", "event_type": "dispatched", "current_location": "WH-A", "delivery_address": "123 Main St, City"}
```

Create the source table with `create_shipments_table.sql`. Then create the historical table with `ddl.shipment_history.sql`, populate it with `dml.shipment_history.sql`, and run the join and ETA placeholder with `dml.compute_eta.sql`. Run with working directory `compute_eta/` or adjust the `path` in each DDL.

The estimation needs to take event timestamps and event types into account.