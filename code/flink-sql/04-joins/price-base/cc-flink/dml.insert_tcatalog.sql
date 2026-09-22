-- Seed catalogs — medical device home monitoring domain.
--
-- Three catalogs covering the test scenarios:
--   1  — Direct-to-Patient catalog  (en_US, MASTER) — devices sold direct to patients
--   2  — Hospital & Clinic catalog  (en_US)         — institutional / procurement pricing
--   3  — Distributor catalog        (en_US)          — channel partner / reseller pricing
--
-- Column order: UIDPK, MASTER, NAME, DEFAULT_LOCALE, CATALOG_CODE

INSERT INTO tcatalog VALUES
--  UIDPK  MASTER  NAME                            DEFAULT_LOCALE  CATALOG_CODE
    (1,     1,      'Direct-to-Patient Catalog',    'en_US',        'DIRECT_PATIENT'),
    (2,     0,      'Hospital and Clinic Catalog',  'en_US',        'HOSPITAL_CLINIC'),
    (3,     0,      'Distributor Catalog',          'en_US',        'DISTRIBUTOR');
