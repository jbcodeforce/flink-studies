-- -----------------------------------------------------------------------------
-- Customer Envelope Processing with Enhanced Metadata
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Extracts data from Debezium envelope with comprehensive CDC metadata
-- Enhanced version includes:
-- - Comprehensive metadata extraction (source timestamps, Kafka offsets, etc.)
-- - is_deleted boolean flag for easier filtering
-- - Snapshot flag to distinguish initial load vs. incremental changes
-- - Source database/table information for multi-source scenarios

-- Basic extraction (original pattern)
INSERT INTO txp_dim_customers 
SELECT 
    -- Business fields extracted from before/after based on operation type
    COALESCE(IF(op = 'd', before.account_number, after.account_number), '') AS account_number,
    COALESCE(IF(op = 'd', before.customer_name, after.customer_name), 'NULL') AS customer_name,
    COALESCE(IF(op = 'd', before.email, after.email), 'NULL') AS email,
    COALESCE(IF(op = 'd', before.phone_number, after.phone_number), 'NULL') AS phone_number,
    DATE_FORMAT(IF(op = 'd', before.date_of_birth, after.date_of_birth), 'YYYY-MM-DD') AS date_of_birth,
    COALESCE(IF(op = 'd', before.city, after.city), 'NULL') AS city,
    COALESCE(IF(op = 'd', before.created_at, after.created_at), 'NULL') AS created_at,
    
    -- CDC operation type
    op AS src_op,
    (op = 'd') AS is_deleted,
    -- Source timestamp
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS src_timestamp
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;