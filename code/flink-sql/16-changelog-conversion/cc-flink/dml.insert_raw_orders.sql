-- Seed data for d16_raw_orders.
-- Each row carries a custom op code in the 'op' column — exactly the format
-- FROM_CHANGELOG is designed to consume.
--
-- Op code convention (matches the Confluent how-to guide example):
--   'c'  → INSERT          (row created for the first time)
--   'ub' → UPDATE_BEFORE   (snapshot of the row BEFORE an update)
--   'ua' → UPDATE_AFTER    (snapshot of the row AFTER the update)
--   'd'  → DELETE          (row removed)
--
-- order_id = 1 goes through a full lifecycle: create → update → delete.
-- order_id = 2..5 are plain creates, providing meaningful input to any
-- aggregation built on top of d16_orders.

INSERT INTO d16_raw_orders (order_id, user_id, product_id, quantity, amount, op) VALUES
    -- order 1: full lifecycle (create, update amount, then delete)
    (1, 'user_1', 'APPLE',   3, 9.00,  'c'),
    (1, 'user_1', 'APPLE',   3, 9.00,  'ub'),   -- before: amount was 9.00
    (1, 'user_1', 'APPLE',   3, 12.00, 'ua'),   -- after:  amount is  12.00
    (1, 'user_1', 'APPLE',   3, 12.00, 'd'),    -- deleted

    -- order 2: plain create
    (2, 'user_2', 'BANANA',  5, 7.50,  'c'),

    -- order 3: create then price correction
    (3, 'user_1', 'PIZZA',   2, 18.00, 'c'),
    (3, 'user_1', 'PIZZA',   2, 18.00, 'ub'),   -- before
    (3, 'user_1', 'PIZZA',   2, 20.00, 'ua'),   -- after: price corrected

    -- order 4: plain create
    (4, 'user_3', 'RAISIN',  4, 6.00,  'c'),

    -- order 5: plain create
    (5, 'user_2', 'POPCORN', 1, 3.50,  'c');
