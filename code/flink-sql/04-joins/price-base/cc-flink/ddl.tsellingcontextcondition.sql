-- Selling context condition table.
--
-- Stores individual eligibility conditions attached to a selling context
-- (e.g. "customer group = VIP", "shopper locale = en_US", "store = CA").
-- Multiple rows can share the same SELLING_CONTEXT_UID — all conditions
-- for a context are AND-ed together when evaluating buyer eligibility.
--
-- Relationship:
--   SELLING_CONTEXT_UID → tsellingcontext.UIDPK
--
-- There is no independent surrogate key in the source schema; the natural
-- key is (SELLING_CONTEXT_UID, CONDITION_GUID).  Flink requires a single-
-- column or composite PRIMARY KEY for upsert changelog mode — use the
-- composite here.
--
-- Changelog mode: upsert — conditions can be added or removed; the latest
-- state per (SELLING_CONTEXT_UID, CONDITION_GUID) pair is authoritative.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention (dimension table)

CREATE TABLE IF NOT EXISTS tsellingcontextcondition (
    SELLING_CONTEXT_UID  BIGINT  NOT NULL,   -- FK → tsellingcontext.UIDPK
    CONDITION_GUID       STRING  NOT NULL,   -- varchar(64) — identifies the specific condition
    PRIMARY KEY (SELLING_CONTEXT_UID, CONDITION_GUID) NOT ENFORCED
) DISTRIBUTED BY HASH(SELLING_CONTEXT_UID, CONDITION_GUID) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
