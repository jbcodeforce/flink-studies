# estimate_delivery Python UDF

First [see Confluent UDF in Python product documnetation](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html) and [flink OSS UDF in python](https://nightlies.apache.org/flink/flink-docs-release-2.0/docs/dev/python/table/udfs/overview/).


Mock PyFlink table function for the compute_eta. The UDF takes `(current_location, delivery_address, event_ts)` and returns one row: `eta_window_start`, `eta_window_end`, `confidence`. It is invoked once per shipment via a LATERAL join in `dml.shipment_history.sql`.

## Usage

* ShipmentEvents are:
    ```json
    {"event_id": "SE01", "shipment_id": "SHP001", "package_id": "PKG-123", "event_ts": "2025-01-30T10:00:00Z", "event_type": "dispatched", "current_location": "WH-A", "delivery_address": "123 Main St, City"}
    {"event_id": "SE02", "shipment_id": "SHP001", "package_id": "PKG-123", "event_ts": "2025-01-30T14:30:00Z", "event_type": "in_transit", "current_location": "HUB-B", "delivery_address": "123 Main St, City"}
    {"event_id": "SE03", "shipment_id": "SHP001", "package_id": "PKG-123", "event_ts": "2025-01-31T09:15:00Z", "event_type": "in_transit", "current_location": "37.3541N,121.9552W "delivery_address": "123 Main St, City"}
    ```

* The UDF will return the following information for each event
    | event_id | eta_window_start | eta_window_end | confidence |
    | --- | --- | --- | --- |
    | SE01 | 2025-01-31T17:00:00 | 2025-01-31T19:00:00 | 0.9 |
    | SE02 | 2025-01-31T17:00:00 | 2025-01-31T19:00:00 | 0.75 |
    | SE03 | 2025-01-31T18:00:00 | 2025-01-31T19:30:00 | 0.85 |


Add a dependency on apache-flink to have access to the PyFlink UDF API. 

## Developing Python based Flink UDF

The steps can be summarized as:

1. Create a new "library" project with your desired name and Python version
    ```sh
    uv 
    ```

## Install

From this directory (uv project):

```sh
uv sync
```

