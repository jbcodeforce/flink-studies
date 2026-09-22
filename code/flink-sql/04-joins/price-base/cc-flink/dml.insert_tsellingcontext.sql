-- Seed selling contexts — medical device home monitoring domain.
--
-- A selling context qualifies WHICH buyers a price list assignment applies to.
--
--   10  — Individual Patient        — direct consumer purchase, standard retail price
--   20  — Licensed Clinician        — qualified healthcare provider, clinical discount
--   30  — Certified Distributor     — channel partner, volume/reseller pricing
--
-- PRIORITY: lower value = higher precedence (same convention as tpricelistassignment).
--
-- Column order: UIDPK, GUID, NAME, DESCRIPTION, PRIORITY

INSERT INTO tsellingcontext VALUES
--  UIDPK  GUID                      NAME                      DESCRIPTION                                               PRIORITY
    (10,    'sc-patient-direct',      'Individual Patient',     'End consumer purchasing a device for personal home use',  1),
    (20,    'sc-clinician-licensed',  'Licensed Clinician',     'Credentialed healthcare provider, clinical pricing',      2),
    (30,    'sc-distributor-cert',    'Certified Distributor',  'Authorised channel partner, volume reseller pricing',     1);
