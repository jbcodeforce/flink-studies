-- Seed orders for customer 101 within a 60s OVER window (base time 2024-06-01 10:00:00).
-- Expected order_count_10s for customer 101: 1, 2, 3, 4, 1
INSERT INTO d06_orders
VALUES
    (1, 101, 'Alice',   TIMESTAMP '2024-06-01 10:00:00.000',  50.00),
    (2, 101, 'Alice',   TIMESTAMP '2024-06-01 10:00:05.000',  75.00),
    (3, 101, 'Alice',   TIMESTAMP '2024-06-01 10:00:18.000',  25.00),
    (4, 101, 'Alice',   TIMESTAMP '2024-06-01 10:00:36.000', 100.00),
    (5, 101, 'Alice',   TIMESTAMP '2024-06-01 10:01:25.000',  40.00),
    (6, 102, 'Bob',     TIMESTAMP '2024-06-01 10:01:00.000', 120.00);
