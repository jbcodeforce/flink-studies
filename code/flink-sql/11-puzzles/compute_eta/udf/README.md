# estimate_delivery UDF (Python mock)

Mock PyFlink table function for the compute_eta puzzle. The UDF takes `(current_location, delivery_address, event_ts)` and returns one row: `eta_window_start`, `eta_window_end`, `risk_score`, `confidence`. It is invoked once per shipment via a LATERAL join in `dml.shipment_history.sql`.

[See Confluent UDF in Python product documnetation](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html) and [flink OSS UDF in python](https://nightlies.apache.org/flink/flink-docs-release-2.0/docs/dev/python/table/udfs/overview/).

Add a dependency on apache-flink to have access to the PyFlink UDF API. 

## Install

From this directory (uv project):

```sh
uv sync
```

