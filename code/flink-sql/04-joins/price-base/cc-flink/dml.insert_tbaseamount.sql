-- Seed base amounts (price entries) — medical device home monitoring domain.
--
-- Products (generic names):
--   prod-monitor-a          — home vital-signs monitor (flagship device)
--   sku-monitor-a-basic     — basic SKU (no cellular, Wi-Fi only)
--   sku-monitor-a-cellular  — cellular SKU (built-in LTE)
--   prod-sensor-b           — wearable biosensor patch (disposable, single-use)
--   prod-hub-c              — connectivity hub (links multiple sensors to cloud)
--
-- Quantity tiers:
--   1.00  — single unit / single-patient purchase
--   10.00 — clinical / facility bulk tier (10+ units)
--
-- Test-case coverage per scenario:
--
--   BA-1xx  PL-100 (Direct USD, ACTIVE)
--     BA-101  monitor-a (product)    qty=1   start past, end future  → ACTIVE → emit
--     BA-102  sku-monitor-a-basic    qty=1   start past, end future  → ACTIVE → emit
--     BA-103  sku-monitor-a-cellular qty=1   start past, end future  → ACTIVE → emit
--     BA-104  sensor-b               qty=1   start past, end future  → ACTIVE → emit
--
--   BA-2xx  PL-200 (Clinical USD, ACTIVE)
--     BA-201  monitor-a (product)    qty=1                           → ACTIVE → emit
--     BA-202  monitor-a              qty=10  bulk / facility tier    → ACTIVE → emit
--     BA-203  sensor-b               qty=1                           → ACTIVE → emit
--     BA-204  hub-c                  qty=1                           → ACTIVE → emit
--
--   BA-3xx  PL-300 (Distributor USD, ACTIVE) — volume/reseller discounts
--     BA-301  monitor-a (product)    qty=1                           → ACTIVE → emit
--     BA-302  sensor-b               qty=1                           → ACTIVE → emit
--     BA-303  hub-c                  qty=1                           → ACTIVE → emit
--     BA-304  monitor-a              qty=10  bulk distributor tier   → ACTIVE → emit
--
--   BA-4xx  PL-400 (Direct USD FUTURE — price list start_date 2025-07-01)
--     BA-401  monitor-a              qty=1   price arrived months early
--             Price list NOT yet active → entire assignment SUPPRESSED (test: nothing emitted)
--
--   BA-5xx  PL-500 (Direct USD EXPIRED — price list end_date 2024-12-31)
--     BA-501  monitor-a              qty=1   promo window closed
--             Price list EXPIRED → RETRACTION required downstream
--
--   BA-6xx  PL-600 (Distributor EUR, ACTIVE)
--     BA-601  monitor-a              qty=1                           → ACTIVE → emit
--     BA-602  sensor-b               qty=1                           → ACTIVE → emit
--
--   BA-7xx  PL-100 (Direct USD) — tbaseamount-level FUTURE window
--     BA-701  hub-c                  qty=1   start_date = 2025-06-01 (future)
--             Price list ACTIVE but THIS price entry not yet valid  → SUPPRESSED
--
--   BA-8xx  PL-100 (Direct USD) — tbaseamount-level EXPIRED window
--     BA-801  sku-monitor-a-basic    qty=1   end_date = 2024-12-01 (past)
--             Price list ACTIVE but THIS price entry expired        → RETRACTION required
--
-- Column order:
--   UIDPK, GUID, OBJECT_GUID, OBJECT_TYPE, QUANTITY, LIST, SALE, PRICE_LIST_GUID,
--   start_date, end_date

INSERT INTO tbaseamount VALUES
--  UIDPK   GUID        OBJECT_GUID                  OBJECT_TYPE    QUANTITY  LIST      SALE      PRICE_LIST_GUID  start_date                                          end_date

    -- ── PL-100: Direct USD ACTIVE ───────────────────────────────────────────────────────────────
    (101,   'ba-101',   'prod-monitor-a',             'Product',     1.00,     349.99,   299.99,  'PL-100',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (102,   'ba-102',   'sku-monitor-a-basic',        'ProductSku',  1.00,     299.99,   259.99,  'PL-100',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (103,   'ba-103',   'sku-monitor-a-cellular',     'ProductSku',  1.00,     399.99,   349.99,  'PL-100',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (104,   'ba-104',   'prod-sensor-b',              'Product',     1.00,      49.99,    39.99,  'PL-100',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),

    -- ── PL-200: Clinical USD ACTIVE ─────────────────────────────────────────────────────────────
    (201,   'ba-201',   'prod-monitor-a',             'Product',     1.00,     279.99,   CAST(NULL AS DECIMAL),    'PL-200',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (202,   'ba-202',   'prod-monitor-a',             'Product',     10.00,    249.99,   CAST(NULL AS DECIMAL),    'PL-200',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (203,   'ba-203',   'prod-sensor-b',              'Product',     1.00,      39.99,   CAST(NULL AS DECIMAL),    'PL-200',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (204,   'ba-204',   'prod-hub-c',                 'Product',     1.00,     149.99,   CAST(NULL AS DECIMAL),    'PL-200',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),

    -- ── PL-300: Distributor USD ACTIVE (volume reseller discounts) ──────────────────────────────
    (301,   'ba-301',   'prod-monitor-a',             'Product',     1.00,     229.99,   CAST(NULL AS DECIMAL),    'PL-300',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (302,   'ba-302',   'prod-sensor-b',              'Product',     1.00,      29.99,   CAST(NULL AS DECIMAL),    'PL-300',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (303,   'ba-303',   'prod-hub-c',                 'Product',     1.00,     119.99,   CAST(NULL AS DECIMAL),    'PL-300',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (304,   'ba-304',   'prod-monitor-a',             'Product',     10.00,    199.99,   CAST(NULL AS DECIMAL),    'PL-300',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),

    -- ── PL-400: Direct USD FUTURE price list (start_date 2025-07-01) ────────────────────────────
    -- Record arrived months early (next-gen device pre-loaded); price list not yet active → SUPPRESSED
    (401,   'ba-401',   'prod-monitor-a',             'Product',     1.00,     449.99,   399.99,  'PL-400',        TO_TIMESTAMP_LTZ('2025-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2026-06-30 23:59:59')),

    -- ── PL-500: Direct USD EXPIRED price list (end_date 2024-12-31) ─────────────────────────────
    -- Introductory promo closed; price list expired → RETRACTION required downstream
    (501,   'ba-501',   'prod-monitor-a',             'Product',     1.00,     319.99,   269.99,  'PL-500',        TO_TIMESTAMP_LTZ('2024-06-01 00:00:00'),  TO_TIMESTAMP_LTZ('2024-12-31 23:59:59')),

    -- ── PL-600: Distributor EUR ACTIVE ──────────────────────────────────────────────────────────
    (601,   'ba-601',   'prod-monitor-a',             'Product',     1.00,     209.99,   CAST(NULL AS DECIMAL),    'PL-600',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (602,   'ba-602',   'prod-sensor-b',              'Product',     1.00,      27.99,   CAST(NULL AS DECIMAL),    'PL-600',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),

    -- ── PL-100: tbaseamount-level FUTURE window ─────────────────────────────────────────────────
    -- Price list ACTIVE but THIS price entry's own start_date is in the future → SUPPRESSED
    (701,   'ba-701',   'prod-hub-c',                 'Product',     1.00,     179.99,   159.99,  'PL-100',        TO_TIMESTAMP_LTZ('2025-06-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),

    -- ── PL-100: tbaseamount-level EXPIRED window ────────────────────────────────────────────────
    -- Price list ACTIVE but THIS price entry's own end_date has passed → RETRACTION required
    (801,   'ba-801',   'sku-monitor-a-basic',        'ProductSku',  1.00,     289.99,   249.99,  'PL-100',        TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2024-12-01 23:59:59'));
