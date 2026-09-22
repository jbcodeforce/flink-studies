-- Seed product SKUs — medical device home monitoring domain.
--
-- SKUs correspond to the ProductSku entries used in dml.insert_tbaseamount.sql:
--   sku-monitor-a-basic     — home monitor, Wi-Fi only SKU  (Direct-to-Patient catalog)
--   sku-monitor-a-cellular  — home monitor, cellular LTE SKU (Direct-to-Patient catalog)
--
-- Both SKUs belong to DIRECT_PATIENT catalog; sku-monitor-a-basic also
-- appears in PL-100 with an expired tbaseamount window (BA-801) to test
-- the price-entry-level retraction scenario.
--
-- Column order: UIDPK, GUID, CATALOG_CODE

INSERT INTO tproductsku VALUES
--  UIDPK  GUID                      CATALOG_CODE
    (10,   'sku-monitor-a-basic',    'DIRECT_PATIENT'),
    (20,   'sku-monitor-a-cellular', 'DIRECT_PATIENT');
