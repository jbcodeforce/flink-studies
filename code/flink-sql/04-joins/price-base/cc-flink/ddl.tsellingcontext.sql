-- Selling context reference table.
--
-- A selling context defines a named buyer segment or sales channel (e.g.
-- "Registered B2B buyers in North America") that qualifies which price list
-- assignments apply to an incoming order.  Conditions are stored separately
-- in tsellingcontextcondition (keyed by SELLING_CONTEXT_UID).
--
-- Relationships:
--   tpricelistassignment.SELLING_CTX_UID  → tsellingcontext.UIDPK
--   tsellingcontextcondition.SELLING_CONTEXT_UID → tsellingcontext.UIDPK
--
-- PRIORITY determines which selling context wins when multiple match a buyer.
-- Lower values = higher precedence (same convention as tpricelistassignment).
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention (dimension table)
--
-- Changelog mode: upsert — context metadata (name, description, priority)
-- can be updated; only the current version per UIDPK is relevant.

CREATE TABLE IF NOT EXISTS tsellingcontext (
    UIDPK       BIGINT  NOT NULL,
    GUID        STRING,     -- varchar(64)
    NAME        STRING,     -- varchar(255)
    DESCRIPTION STRING,     -- varchar(255)
    PRIORITY    INT,
    PRIMARY KEY (UIDPK) NOT ENFORCED
) DISTRIBUTED BY HASH(UIDPK) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
