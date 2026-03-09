-- Flink SQL Deduplication Demo
-- This script reads product events from Kafka, deduplicates them, and creates a src_products table
--
-- Usage:
-- 1. Start Flink SQL CLI: sql-client.sh
-- 2. Execute this script: SOURCE 'flink-deduplication.sql';
-- 3. Query the results: SELECT * FROM src_products;

-- ============================================================================
-- 1. CREATE SOURCE TABLE FOR KAFKA PRODUCT EVENTS
-- ============================================================================

-- Drop tables if they exist (for re-running the script)
DROP TABLE IF EXISTS product_events_raw;
DROP VIEW IF EXISTS product_events_flattened;
DROP VIEW IF EXISTS product_events_deduplicated;
DROP TABLE IF EXISTS src_products;

-- Create the source table to read from Kafka topic 'products'
CREATE TABLE product_events_raw (
    event_id STRING,
    action STRING,
    `timestamp` TIMESTAMP(3),
    processed BOOLEAN,
    product ROW<
        product_id INT,
        product_name STRING,
        description STRING,
        price DECIMAL(10,2),
        stock_quantity INT,
        discount DECIMAL(10,2),
        created_at TIMESTAMP(3),
        updated_at TIMESTAMP(3)
    >,
    old_price DECIMAL(10,2),
    -- Define watermark for event time processing
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'products',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'flink-dedup-consumer',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- ============================================================================
-- 2. FLATTEN THE NESTED PRODUCT STRUCTURE
-- ============================================================================

-- Create a view to flatten the nested product structure for easier processing
CREATE VIEW product_events_flattened AS
SELECT 
    event_id,
    action,
    `timestamp` as event_timestamp,
    processed,
    product.product_id,
    product.product_name,
    product.description,
    product.price,
    product.stock_quantity,
    product.discount,
    product.created_at,
    product.updated_at,
    old_price,
    -- Add processing time for debugging
    PROCTIME() as processing_time
FROM product_events_raw
WHERE product.product_id IS NOT NULL;  -- Filter out malformed events

-- ============================================================================
-- 3. IMPLEMENT DEDUPLICATION LOGIC
-- ============================================================================

-- Create a view that deduplicates events based on product_id and event content
-- Keep the most recent event for each unique product state
CREATE VIEW product_events_deduplicated AS
SELECT 
    event_id,
    action,
    event_timestamp,
    processed,
    product_id,
    product_name,
    description,
    price,
    stock_quantity,
    discount,
    created_at,
    updated_at,
    old_price,
    processing_time
FROM (
    SELECT *,
           -- Use ROW_NUMBER to identify duplicates
           -- Partition by product_id and current state (price, stock, etc.)
           -- Order by event_timestamp DESC to keep the latest event
           ROW_NUMBER() OVER (
               PARTITION BY 
                   product_id,
                   product_name,
                   description,
                   price,
                   stock_quantity,
                   discount
               ORDER BY event_timestamp DESC
           ) as row_num
    FROM product_events_flattened
) ranked_events
WHERE row_num = 1;  -- Keep only the first (most recent) occurrence

-- ============================================================================
-- 4. CREATE THE FINAL src_products TABLE
-- ============================================================================

-- Create the destination table that will contain deduplicated product data
CREATE TABLE src_products (
    product_id INT,
    product_name STRING,
    description STRING,
    price DECIMAL(10,2),
    stock_quantity INT,
    discount DECIMAL(10,2),
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    last_event_id STRING,
    last_action STRING,
    last_event_timestamp TIMESTAMP(3),
    last_old_price DECIMAL(10,2),
    processing_time TIMESTAMP(3),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'src_products',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json',
    'value.json.timestamp-format.standard' = 'ISO-8601'
);

-- ============================================================================
-- 5. INSERT DEDUPLICATED DATA INTO src_products TABLE
-- ============================================================================

-- Insert the deduplicated product events into the destination table
INSERT INTO src_products
SELECT 
    product_id,
    product_name,
    description,
    price,
    stock_quantity,
    discount,
    created_at,
    updated_at,
    event_id as last_event_id,
    action as last_action,
    event_timestamp as last_event_timestamp,
    old_price as last_old_price,
    processing_time
FROM product_events_deduplicated;

-- ============================================================================
-- 6. OPTIONAL: CREATE MONITORING VIEWS
-- ============================================================================

-- View to monitor deduplication effectiveness
CREATE VIEW deduplication_stats AS
SELECT 
    COUNT(*) as total_events,
    COUNT(DISTINCT product_id) as unique_products,
    COUNT(*) - COUNT(DISTINCT product_id) as duplicate_events_removed,
    CAST((COUNT(*) - COUNT(DISTINCT product_id)) AS DOUBLE) / COUNT(*) * 100 as duplicate_percentage
FROM product_events_flattened;

-- View to see the most recent state of each product
CREATE VIEW current_product_state AS
SELECT 
    product_id,
    product_name,
    price,
    stock_quantity,
    discount,
    last_action,
    last_event_timestamp,
    processing_time
FROM src_products
ORDER BY product_id;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*
-- Query examples (run these after the tables are created and populated):

-- 1. Check deduplication effectiveness
SELECT * FROM deduplication_stats;

-- 2. View current product states
SELECT * FROM current_product_state;

-- 3. Monitor incoming events
SELECT product_id, action, event_timestamp 
FROM product_events_flattened 
ORDER BY event_timestamp DESC 
LIMIT 10;

-- 4. Compare raw vs deduplicated counts
SELECT 
    'Raw Events' as source, COUNT(*) as count 
FROM product_events_flattened
UNION ALL
SELECT 
    'Deduplicated' as source, COUNT(*) as count 
FROM product_events_deduplicated;

-- 5. View products with recent price changes
SELECT 
    product_id, 
    product_name, 
    price, 
    last_old_price,
    last_event_timestamp
FROM src_products 
WHERE last_action = 'price_changed' 
AND last_old_price IS NOT NULL
ORDER BY last_event_timestamp DESC;
*/ 