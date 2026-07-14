-- Seed one event per union branch for demo validation.
INSERT INTO account_events VALUES
    (
        'corr-swap-001',
        ROW('DeviceSwap', 'corr-swap-001', 'billing-system'),
        ROW(
            ROW('acc-001', 'dev-99'),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
    ),
    (
        'corr-sub-001',
        ROW('Subscription', 'corr-sub-001', 'billing-system'),
        ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            ROW('acc-002', 'ACTIVE', 'plan-premium'),
            CAST(NULL AS ROW<accountId STRING, reasonCode STRING>)
        )
    ),
    (
        'corr-close-001',
        ROW('DeviceClose', 'corr-close-001', 'device-service'),
        ROW(
            CAST(NULL AS ROW<accountId STRING, deviceId STRING>),
            CAST(NULL AS ROW<accountId STRING, status STRING, planId STRING>),
            ROW('acc-003', 'CUSTOMER_REQUEST')
        )
    );
