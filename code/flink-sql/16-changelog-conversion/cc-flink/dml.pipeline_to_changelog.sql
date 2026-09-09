-- TO_CHANGELOG pipeline: bridge Flink row kinds → custom CDC op codes.
--
-- Reads d16_order_count (Flink updating / upsert table) and uses the TO_CHANGELOG
-- Process Table Function (PTF) to convert each internal Flink row kind into
-- an explicit op code a non-Flink consumer can act on:
--
--   INSERT        → 'c'   (create)
--   UPDATE_AFTER  → 'u'   (update — only the new value, no before-image)
--   DELETE        → 'd'   (delete)
--
-- UPDATE_BEFORE is intentionally omitted: downstream consumers (microservices,
-- Connect sinks) typically only need the current/final value, not the snapshot
-- before the change.
--
-- The result is appended to d16_fct_product_usage (append-only topic).  Every row
-- there — including a delete — is a fully serialised Kafka record with a
-- non-null value and an explicit 'op' field.  This is different from a Kafka
-- tombstone (null value); use it when the consumer cannot handle tombstones.
--
-- TO_CHANGELOG output is always append-only: it can be read directly by a
-- SELECT or a downstream pipeline without any materialisation workaround.
--
-- PARTITION BY product_id ensures all changes for the same key arrive at the
-- same Flink task in order.

INSERT INTO d16_fct_product_usage
SELECT * FROM TO_CHANGELOG(
    input      => TABLE d16_order_count PARTITION BY product_id,
    op         => DESCRIPTOR(op),
    op_mapping => MAP[
        'INSERT',       'c',
        'UPDATE_AFTER', 'u',
        'DELETE',       'd'
    ]
);
