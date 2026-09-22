-- Seed price list assignments — medical device home monitoring domain.
--
-- Binds (catalog × selling-context × price-list) together.
-- Each row answers: "for buyers in THIS context, browsing THIS catalog,
-- apply THAT price list — at this priority".
--
-- Test-case matrix:
--   ID   Catalog               Context               Price list         Scenario
--   ──── ───────────────────── ───────────────────── ────────────────── ─────────────────────────────────────────────
--   1001 Direct-to-Patient(1)  Individual Patient(10) PL-100 Direct USD  ACTIVE   → emit prices
--   1002 Hospital & Clinic(2)  Licensed Clinician(20) PL-200 Clinical USD ACTIVE  → emit clinical prices
--   1003 Distributor(3)        Certified Distrib.(30) PL-300 Distrib. USD ACTIVE  → emit distributor prices
--   1004 Direct-to-Patient(1)  Individual Patient(10) PL-400 Next-Gen    FUTURE   → suppressed until 2025-07-01
--   1005 Direct-to-Patient(1)  Individual Patient(10) PL-500 Intro Promo EXPIRED  → retraction required
--   1006 Hospital & Clinic(2)  Licensed Clinician(20) PL-200 Clinical USD ACTIVE  → clinical path via hospital catalog
--   1007 Distributor(3)        Certified Distrib.(30) PL-600 Distrib. EUR ACTIVE  → EU EUR distributor path
--
-- PRIORITY within the same catalog+context: lower value = wins.
-- Assignments 1001 and 1004 share catalog(1)+context(10); 1001 wins while 1004 is suppressed.
--
-- Column order: UIDPK, GUID, NAME, DESCRIPTION, PRIORITY, CATALOG_UID, PRLISTDSCR_UID, SELLING_CTX_UID

INSERT INTO tpricelistassignment VALUES
--  UIDPK  GUID       NAME                               DESCRIPTION                                                  PRIORITY  CATALOG_UID  PRLISTDSCR_UID  SELLING_CTX_UID
    (1001,  'pla-001', 'Patient Direct USD Standard',    'Active USD standard retail price for direct patient sales',  1,        1,           100,            10),
    (1002,  'pla-002', 'Clinical USD Discount',          'Active USD clinical price for licensed clinicians',          1,        2,           200,            20),
    (1003,  'pla-003', 'Distributor USD Volume',         'Active USD volume price for certified distributors',         1,        3,           300,            30),
    -- Future assignment: PL-400 start_date = 2025-07-01 — must be suppressed today
    (1004,  'pla-004', 'Patient Direct USD Next-Gen',    'Next-gen launch price — NOT yet active, suppress until July', 2,       1,           400,            10),
    -- Expired assignment: PL-500 end_date = 2024-12-31 — retraction required
    (1005,  'pla-005', 'Patient Direct USD Intro Promo', 'Introductory promo — EXPIRED, retraction required',          3,        1,           500,            10),
    (1006,  'pla-006', 'Hospital Clinician USD Discount','Active USD clinical price via hospital catalog',              1,        2,           200,            20),
    (1007,  'pla-007', 'Distributor EUR Volume',         'Active EUR volume price for EU channel partners',             1,        3,           600,            30);
