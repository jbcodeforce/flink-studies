-- Join shipment events with historical table to compute ETA.
-- Run after dml.shipment_history.sql has populated shipment_history.
SELECT
    e.shipment_id,
    e.package_id,
    e.event_ts,
    e.event_type,
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
FROM shipment_events e
JOIN shipment_history h ON e.shipment_id = h.shipment_id;
