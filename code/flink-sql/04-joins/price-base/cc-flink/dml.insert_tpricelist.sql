-- Seed price lists — medical device home monitoring domain.
--
-- Six price lists designed to exercise every temporal test case:
--
--   PL-100  Direct USD     — ACTIVE: standard retail price for direct-to-patient sales
--   PL-200  Clinical USD   — ACTIVE: clinical discount price for licensed clinicians
--   PL-300  Distributor USD— ACTIVE: volume/reseller price for certified distributors
--   PL-400  Direct USD     — NOT YET ACTIVE (start_date 2025-07-01): next-generation
--                            device launch pricing, records sent months in advance
--                            → must be suppressed until launch date
--   PL-500  Direct USD     — EXPIRED (end_date 2024-12-31): introductory launch promo
--                            → must trigger retraction downstream
--   PL-600  Distributor EUR— ACTIVE: EUR distributor pricing for EU channel partners
--
-- Timestamps use a fixed reference date of 2025-01-15 as "today" so the
-- test dataset remains deterministic regardless of when it is loaded.
--
-- Column order: UIDPK, GUID, NAME, CURRENCY, DESCRIPTION, start_date, end_date

INSERT INTO tpricelist VALUES
--  UIDPK  GUID      NAME                           CURRENCY  DESCRIPTION                                            start_date                                          end_date
    (100,  'PL-100', 'Direct Patient USD Standard', 'USD',    'Standard USD retail price for direct patient sales',  TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (200,  'PL-200', 'Clinical USD Discount',       'USD',    'Clinical USD price for licensed healthcare providers', TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    (300,  'PL-300', 'Distributor USD Volume',      'USD',    'Volume USD reseller price for certified distributors', TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59')),
    -- Future price list: start_date = 2025-07-01 — next-gen device launch; suppress until then
    (400,  'PL-400', 'Direct USD Next-Gen Launch',  'USD',    'Next-generation device launch price — NOT yet active', TO_TIMESTAMP_LTZ('2025-07-01 00:00:00'),  TO_TIMESTAMP_LTZ('2026-06-30 23:59:59')),
    -- Expired price list: end_date = 2024-12-31 — introductory promo now closed
    (500,  'PL-500', 'Direct USD Intro Promo',      'USD',    'Introductory launch promo — EXPIRED, retract downstream',TO_TIMESTAMP_LTZ('2024-06-01 00:00:00'),TO_TIMESTAMP_LTZ('2024-12-31 23:59:59')),
    (600,  'PL-600', 'Distributor EUR Volume',      'EUR',    'Volume EUR reseller price for EU channel partners',    TO_TIMESTAMP_LTZ('2024-01-01 00:00:00'),  TO_TIMESTAMP_LTZ('2025-12-31 23:59:59'));
