-- Join package_events with package_eta_history to produce ETA-enriched stream.
-- Run after dml.package_eta_history.sql has populated package_eta_history.
SELECT
    e.package_id,
    e.event_ts,
    e.status,
    e.expected_ts,
    e.event_type,
    e.payload,
    e.current_location,
    e.delivery_address,
    h.event_history,
    h.ETA_2h_time_window_start,
    h.ETA_2h_time_window_end,
    h.ETA_day,
    h.shipment_status,
    h.previous_ETA_2h_time_window_start,
    h.previous_ETA_2h_time_window_end,
    h.risk_score,
    h.confidence
FROM package_events e
JOIN package_eta_history h ON e.package_id = h.package_id;
