# estimate_delivery UDF (Python mock)

Mock PyFlink table function for the compute_eta puzzle. The UDF takes `(current_location, delivery_address, event_ts)` and returns one row: `eta_window_start`, `eta_window_end`, `risk_score`, `confidence`. It is invoked once per shipment via a LATERAL join in `dml.shipment_history.sql`.

## Install

From this directory or the repo root:

```sh
pip install -r requirements.txt
```

## Run end-to-end

Run with working directory = `compute_eta` so paths `data/shipment_events.json` and `data/shipment_history` resolve:

```sh
cd compute_eta
python udf/run_eta_poc.py
```

The runner registers the UDF, executes DDL (shipment_events, shipment_history), runs the INSERT that populates shipment_history (calling the UDF), then runs the ETA join query and prints the result.
