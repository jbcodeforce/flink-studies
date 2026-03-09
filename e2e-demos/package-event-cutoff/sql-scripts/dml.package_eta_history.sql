-- Populate package_eta_history from package_events (run after ddl.package_events.sql and ddl.package_eta_history.sql).
-- Requires table function estimate_delivery(current_location, delivery_address, event_ts) returning one row with estimation window and risk (see README).
-- UDF is invoked once per package via LATERAL join.
INSERT INTO package_eta_history (
    package_id,
    event_history,
    ETA_2h_time_window_start,
    ETA_2h_time_window_end,
    ETA_day,
    shipment_status,
    previous_ETA_2h_time_window_start,
    previous_ETA_2h_time_window_end,
    risk_score,
    confidence
)
SELECT
    agg.package_id,
    agg.event_history,
    est.eta_window_start AS ETA_2h_time_window_start,
    est.eta_window_end AS ETA_2h_time_window_end,
    DATE(est.eta_window_start) AS ETA_day,
    agg.shipment_status,
    CAST(NULL AS TIMESTAMP(3)) AS previous_ETA_2h_time_window_start,
    CAST(NULL AS TIMESTAMP(3)) AS previous_ETA_2h_time_window_end,
    est.risk_score,
    est.confidence
FROM (
    SELECT
        package_id,
        ARRAY_AGG(ROW(event_ts, event_type, current_location, delivery_address)) AS event_history,
        MAX_BY(current_location, event_ts) AS current_location_latest,
        MAX_BY(delivery_address, event_ts) AS delivery_address_latest,
        MAX(event_ts) AS event_ts_latest,
        MAX(event_type) AS shipment_status
    FROM package_events
    GROUP BY package_id
) agg
JOIN LATERAL TABLE(estimate_delivery(agg.current_location_latest, agg.delivery_address_latest, agg.event_ts_latest)) AS est(eta_window_start, eta_window_end, risk_score, confidence) ON TRUE;
