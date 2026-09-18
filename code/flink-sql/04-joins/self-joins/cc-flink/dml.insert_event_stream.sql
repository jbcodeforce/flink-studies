-- Seed subscription and deviceSwap events for demo validation.
INSERT INTO event_stream VALUES
    (
        'evt-sub-001',
        TIMESTAMP '2026-06-29 10:05:00.000',
        '{"eventType":"subscription"}',
        ARRAY['{"account_number":"acc-001","plan_name":"Premium","subscription_start":"2026-01-01 00:00:00.000"}']
    ),
    (
        'evt-swap-001',
        TIMESTAMP '2026-06-29 10:10:00.000',
        '{"eventType":"deviceSwap"}',
        ARRAY['{"account_number":"acc-002","old_device_id":"device-old","new_device_id":"device-new"}']
    ),
    (
        'evt-sub-002',
        TIMESTAMP '2026-06-29 10:15:00.000',
        '{"eventType":"subscription"}',
        ARRAY['{"account_number":"acc-010","plan_name":"Family","subscription_start":"2026-02-01 00:00:00.000"}']
    );
