"""
Mock table function estimate_delivery(current_location, delivery_address, event_ts).
Returns one row: eta_window_start, eta_window_end, risk_score, confidence.
Used in compute_eta puzzle via LATERAL join in dml.shipment_history.sql.
"""
from datetime import datetime, timedelta
from pyflink.table import DataTypes
from pyflink.table.types import DataType
from pyflink.table.udf import udf


_int_add_inp_types: list[DataType] = [
    DataTypes.STRING(nullable=False),
    DataTypes.STRING(nullable=False),
    DataTypes.TIMESTAMP(3, nullable=False),
]

def estimate_delivery(current_location: str, delivery_address: str, event_ts):
    """
    Mock ETA: 2h window starting 1 day after event_ts, fixed risk and confidence.
    event_ts is datetime-like from Flink (e.g. datetime.datetime).
    """
    if event_ts is None:
        event_ts = datetime.now()

    base = event_ts.to_local_datetime()
    eta_window_start = base + timedelta(days=1)
    eta_window_end = eta_window_start + timedelta(hours=2)
    risk_score = 0.5
    confidence = 0.8
    return eta_window_start, eta_window_end, risk_score, confidence
