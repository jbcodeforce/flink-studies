-- FROM_CHANGELOG pipeline: bridge custom CDC op codes → Flink row kinds.
--
-- Reads d16_raw_orders (append-only, carries a user-defined 'op' STRING field)
-- and uses the FROM_CHANGELOG Process Table Function (PTF) to translate each
-- custom op code into the matching Flink internal row kind:
--
--   'c'  → INSERT
--   'ub' → UPDATE_BEFORE
--   'ua' → UPDATE_AFTER
--   'd'  → DELETE
--
-- The result is materialised into d16_orders (upsert table with PK order_id).
-- Materialising first is required: a foreground SELECT directly on a
-- FROM_CHANGELOG upsert output can silently return wrong results (known
-- limitation documented at docs.confluent.io).
-- The output includes every input column except the operation-code column, which Flink interprets and removes
-- PARTITION BY order_id ensures all changes for the same key are processed
-- by the same Flink task, preserving event order.

INSERT INTO d16_orders
SELECT order_id, user_id, product_id, quantity, amount
FROM FROM_CHANGELOG(
    input      => TABLE d16_raw_orders PARTITION BY order_id,
    op         => DESCRIPTOR(op),
    op_mapping => MAP[ --  map to row kind
        'c',  'INSERT',
        'ub', 'UPDATE_BEFORE',
        'ua', 'UPDATE_AFTER',
        'd',  'DELETE'
    ]
);
