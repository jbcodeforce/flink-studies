insert into shipment_history (package_id, 
        event_history, 
        ETA_2h_time_window_start, 
        ETA_2h_time_window_end, 
        ETA_day, 
        shipment_status, 
        previous_ETA_2h_time_window_start, 
        previous_ETA_2h_time_window_end, 
        risk_score, 
        confidence)
values (
    'PKG-123',
    array[row(TO_TIMESTAMP('2025-01-30 10:00:00'), 'dispatched', 'WH-A', '123 Main St, City')],
    TO_TIMESTAMP('2025-01-30T10:00:00Z'),
    TO_TIMESTAMP('2025-01-30T14:30:00Z'),
    TO_DATE('2025-01-30'),
    'dispatched',
    TO_TIMESTAMP('2025-01-30T10:00:00Z'),
    TO_TIMESTAMP('2025-01-30T14:00:00Z'),
    0.5,
    0.8
);