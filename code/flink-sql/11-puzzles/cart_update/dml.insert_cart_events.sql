-- Mock cart add events. Run after dml.build_cart_line_items.sql is started.
-- Cart C1 (user U1): Laptop + 2x Mouse. Cart C2 (user U2): Laptop.
INSERT INTO cart_events (
    cart_id, product_id, action, quantity, cart_status, cart_date, user_id, event_ts
)
VALUES
    (
        'C1', 'P001', 'ADD', 1, 'OPEN', DATE '2025-05-01', 'U1',
        TO_TIMESTAMP_LTZ('2025-05-01 10:00:00', 'yyyy-MM-dd HH:mm:ss')
    ),
    (
        'C1', 'P002', 'ADD', 2, 'OPEN', DATE '2025-05-01', 'U1',
        TO_TIMESTAMP_LTZ('2025-05-01 10:01:00', 'yyyy-MM-dd HH:mm:ss')
    ),
    (
        'C2', 'P001', 'ADD', 1, 'OPEN', DATE '2025-05-01', 'U2',
        TO_TIMESTAMP_LTZ('2025-05-01 11:00:00', 'yyyy-MM-dd HH:mm:ss')
    );
