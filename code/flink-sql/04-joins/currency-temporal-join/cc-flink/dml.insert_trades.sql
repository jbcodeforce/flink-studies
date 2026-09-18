-- Seed trades spread across timestamps to exercise different FX rate versions.
--
-- trade_ts uses TO_TIMESTAMP_LTZ to match the TIMESTAMP_LTZ(3) column type.
-- Insert fx_rates FIRST (make deploy-data runs fx_rates seed before trades seed
-- as ordered in deploy_manifest.json) so the versioned table is populated before
-- the temporal join pipeline starts processing trades.

INSERT INTO trades VALUES
-- EUR/USD — three trades hitting three different rate windows
('TRD-001', TO_TIMESTAMP_LTZ('2024-06-01 09:15:00'), 'EUR', 'USD', 100000.00, 'trader_a', 'FX-EMEA'),
('TRD-002', TO_TIMESTAMP_LTZ('2024-06-01 13:30:00'), 'EUR', 'USD',  50000.00, 'trader_b', 'FX-EMEA'),
('TRD-003', TO_TIMESTAMP_LTZ('2024-06-01 17:00:00'), 'EUR', 'USD', 250000.00, 'trader_a', 'FX-EMEA'),

-- GBP/USD — two trades, two rate versions
('TRD-004', TO_TIMESTAMP_LTZ('2024-06-01 10:00:00'), 'GBP', 'USD',  75000.00, 'trader_c', 'FX-London'),
('TRD-005', TO_TIMESTAMP_LTZ('2024-06-01 15:00:00'), 'GBP', 'USD', 120000.00, 'trader_c', 'FX-London'),

-- JPY/USD — large notional, tests decimal precision
('TRD-006', TO_TIMESTAMP_LTZ('2024-06-01 09:00:00'), 'JPY', 'USD', 10000000.00, 'trader_d', 'FX-APAC'),
('TRD-007', TO_TIMESTAMP_LTZ('2024-06-01 11:00:00'), 'JPY', 'USD',  5000000.00, 'trader_d', 'FX-APAC'),

-- CHF/USD — single rate version; both trades resolve the same rate
('TRD-008', TO_TIMESTAMP_LTZ('2024-06-01 08:30:00'), 'CHF', 'USD',  30000.00, 'trader_e', 'FX-EMEA'),
('TRD-009', TO_TIMESTAMP_LTZ('2024-06-01 16:00:00'), 'CHF', 'USD',  80000.00, 'trader_e', 'FX-EMEA'),

-- MXN/USD — no matching FX rate; dropped by INNER JOIN (use LEFT JOIN to keep it)
('TRD-010', TO_TIMESTAMP_LTZ('2024-06-01 11:00:00'), 'MXN', 'USD', 500000.00, 'trader_f', 'FX-LATAM');
