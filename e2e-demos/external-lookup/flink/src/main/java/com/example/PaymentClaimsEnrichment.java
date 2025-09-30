package com.example;

import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Flink Table API application for enriching payment events with claims data
 * using lookup joins against an external DuckDB database.
 * 
 * Architecture:
 * - Reads payment events from Kafka topic 'payment-events'
 * - Performs lookup joins against DuckDB claims table
 * - Writes enriched events to 'enriched-payments' topic
 * - Writes failed lookups to 'failed-payments' topic
 */
public class PaymentClaimsEnrichment {
    
    private static final Logger LOG = LoggerFactory.getLogger(PaymentClaimsEnrichment.class);
    
    // Configuration constants
    private static final String KAFKA_BOOTSTRAP_SERVERS = getEnvOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
    private static final String PAYMENT_EVENTS_TOPIC = getEnvOrDefault("PAYMENT_EVENTS_TOPIC", "payment-events");
    private static final String ENRICHED_PAYMENTS_TOPIC = getEnvOrDefault("ENRICHED_PAYMENTS_TOPIC", "enriched-payments");
    private static final String FAILED_PAYMENTS_TOPIC = getEnvOrDefault("FAILED_PAYMENTS_TOPIC", "failed-payments");
    private static final String DUCKDB_URL = getEnvOrDefault("DUCKDB_URL", "jdbc:duckdb:http://localhost:8080/database");
    
    public static void main(String[] args) throws Exception {
        LOG.info("Starting Payment Claims Enrichment Job");
        
        // Set up the streaming execution environment
        Configuration conf = new Configuration();
        
        // Enable checkpointing for fault tolerance
        conf.setString("execution.checkpointing.interval", "60s");
        conf.setString("execution.checkpointing.mode", "EXACTLY_ONCE");
        
        // Set table configuration for better performance
        conf.setString("table.exec.source.idle-timeout", "30s");
        conf.setString("table.exec.async-lookup.buffer-capacity", "1000");
        conf.setString("table.exec.async-lookup.timeout", "5s");
        conf.setString("table.optimizer.join-reorder-enabled", "true");
        
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment(conf);
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);
        
        // Configure for development/testing (remove in production)
        env.setParallelism(1);
        
        PaymentClaimsEnrichment job = new PaymentClaimsEnrichment();
        job.createTables(tableEnv);
        job.executeEnrichmentPipeline(tableEnv);
        
        LOG.info("Executing Payment Claims Enrichment Job");
        env.execute("Payment Claims Enrichment");
    }
    
    /**
     * Create all necessary tables for the pipeline
     */
    private void createTables(StreamTableEnvironment tableEnv) {
        LOG.info("Creating tables...");
        
        // 1. Create payment events source table (Kafka)
        createPaymentEventsTable(tableEnv);
        
        // 2. Create claims lookup table (JDBC/DuckDB)
        createClaimsLookupTable(tableEnv);
        
        // 3. Create enriched payments sink table (Kafka)
        createEnrichedPaymentsSinkTable(tableEnv);
        
        // 4. Create failed payments sink table (Kafka)
        createFailedPaymentsSinkTable(tableEnv);
        
        LOG.info("All tables created successfully");
    }
    
    /**
     * Create the payment events source table from Kafka
     */
    private void createPaymentEventsTable(StreamTableEnvironment tableEnv) {
        String ddl = String.format(
            "CREATE TABLE payment_events (\n" +
            "    payment_id STRING,\n" +
            "    claim_id STRING,\n" +
            "    payment_amount DECIMAL(10,2),\n" +
            "    payment_date TIMESTAMP(3),\n" +
            "    processor_id STRING,\n" +
            "    payment_method STRING,\n" +
            "    payment_status STRING,\n" +
            "    reference_number STRING,\n" +
            "    transaction_id STRING,\n" +
            "    notes STRING,\n" +
            "    created_by STRING,\n" +
            "    proc_time AS PROCTIME(),\n" +  // Processing time for lookup joins
            "    event_time AS CAST(payment_date AS TIMESTAMP(3)),\n" +
            "    WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND\n" +
            ") WITH (\n" +
            "    'connector' = 'kafka',\n" +
            "    'topic' = '%s',\n" +
            "    'properties.bootstrap.servers' = '%s',\n" +
            "    'properties.group.id' = 'payment-claims-enrichment',\n" +
            "    'scan.startup.mode' = 'latest-offset',\n" +
            "    'format' = 'json',\n" +
            "    'json.fail-on-missing-field' = 'false',\n" +
            "    'json.ignore-parse-errors' = 'true'\n" +
            ")", 
            PAYMENT_EVENTS_TOPIC, KAFKA_BOOTSTRAP_SERVERS);
            
        LOG.info("Creating payment_events table with DDL: {}", ddl);
        tableEnv.executeSql(ddl);
    }
    
    /**
     * Create the claims lookup table from DuckDB
     */
    private void createClaimsLookupTable(StreamTableEnvironment tableEnv) {
        String ddl = String.format(
            "CREATE TABLE claims_lookup (\n" +
            "    claim_id STRING,\n" +
            "    member_id STRING,\n" +
            "    claim_amount DECIMAL(10,2),\n" +
            "    claim_status STRING,\n" +
            "    created_date TIMESTAMP(3)\n" +
            ") WITH (\n" +
            "    'connector' = 'jdbc',\n" +
            "    'url' = '%s',\n" +
            "    'table-name' = 'claims',\n" +
            "    'lookup.cache' = 'LRU',\n" +
            "    'lookup.cache.max-rows' = '10000',\n" +
            "    'lookup.cache.ttl' = '1min',\n" +
            "    'lookup.async' = 'true',\n" +
            "    'lookup.max-retries' = '3'\n" +
            ")", DUCKDB_URL);
            
        LOG.info("Creating claims_lookup table with DDL: {}", ddl);
        tableEnv.executeSql(ddl);
    }
    
    /**
     * Create the enriched payments sink table to Kafka
     */
    private void createEnrichedPaymentsSinkTable(StreamTableEnvironment tableEnv) {
        String ddl = String.format(
            "CREATE TABLE enriched_payments_sink (\n" +
            "    payment_id STRING,\n" +
            "    claim_id STRING,\n" +
            "    payment_amount DECIMAL(10,2),\n" +
            "    payment_date TIMESTAMP(3),\n" +
            "    processor_id STRING,\n" +
            "    payment_method STRING,\n" +
            "    payment_status STRING,\n" +
            "    reference_number STRING,\n" +
            "    transaction_id STRING,\n" +
            "    notes STRING,\n" +
            "    created_by STRING,\n" +
            "    member_id STRING,\n" +
            "    claim_amount DECIMAL(10,2),\n" +
            "    claim_status STRING,\n" +
            "    claim_created_date TIMESTAMP(3),\n" +
            "    enrichment_status STRING,\n" +
            "    enrichment_timestamp TIMESTAMP(3)\n" +
            ") WITH (\n" +
            "    'connector' = 'kafka',\n" +
            "    'topic' = '%s',\n" +
            "    'properties.bootstrap.servers' = '%s',\n" +
            "    'format' = 'json',\n" +
            "    'sink.partitioner' = 'round-robin'\n" +
            ")", ENRICHED_PAYMENTS_TOPIC, KAFKA_BOOTSTRAP_SERVERS);
            
        LOG.info("Creating enriched_payments_sink table with DDL: {}", ddl);
        tableEnv.executeSql(ddl);
    }
    
    /**
     * Create the failed payments sink table to Kafka
     */
    private void createFailedPaymentsSinkTable(StreamTableEnvironment tableEnv) {
        String ddl = String.format(
            "CREATE TABLE failed_payments_sink (\n" +
            "    payment_id STRING,\n" +
            "    claim_id STRING,\n" +
            "    payment_amount DECIMAL(10,2),\n" +
            "    payment_date TIMESTAMP(3),\n" +
            "    processor_id STRING,\n" +
            "    payment_method STRING,\n" +
            "    payment_status STRING,\n" +
            "    reference_number STRING,\n" +
            "    transaction_id STRING,\n" +
            "    notes STRING,\n" +
            "    created_by STRING,\n" +
            "    enrichment_status STRING,\n" +
            "    enrichment_timestamp TIMESTAMP(3),\n" +
            "    error_message STRING\n" +
            ") WITH (\n" +
            "    'connector' = 'kafka',\n" +
            "    'topic' = '%s',\n" +
            "    'properties.bootstrap.servers' = '%s',\n" +
            "    'format' = 'json',\n" +
            "    'sink.partitioner' = 'round-robin'\n" +
            ")", FAILED_PAYMENTS_TOPIC, KAFKA_BOOTSTRAP_SERVERS);
            
        LOG.info("Creating failed_payments_sink table with DDL: {}", ddl);
        tableEnv.executeSql(ddl);
    }
    
    /**
     * Execute the main enrichment pipeline with lookup joins
     */
    private void executeEnrichmentPipeline(StreamTableEnvironment tableEnv) {
        LOG.info("Executing enrichment pipeline...");
        
        // Perform lookup join between payment events and claims
        String enrichmentQuery = 
            "SELECT \n" +
            "    p.payment_id,\n" +
            "    p.claim_id,\n" +
            "    p.payment_amount,\n" +
            "    p.payment_date,\n" +
            "    p.processor_id,\n" +
            "    p.payment_method,\n" +
            "    p.payment_status,\n" +
            "    p.reference_number,\n" +
            "    p.transaction_id,\n" +
            "    p.notes,\n" +
            "    p.created_by,\n" +
            "    c.member_id,\n" +
            "    c.claim_amount,\n" +
            "    c.claim_status,\n" +
            "    c.created_date as claim_created_date,\n" +
            "    CASE \n" +
            "        WHEN c.claim_id IS NOT NULL THEN 'SUCCESS'\n" +
            "        ELSE 'CLAIM_NOT_FOUND'\n" +
            "    END as enrichment_status,\n" +
            "    CURRENT_TIMESTAMP as enrichment_timestamp\n" +
            "FROM payment_events p\n" +
            "LEFT JOIN claims_lookup FOR SYSTEM_TIME AS OF p.proc_time AS c\n" +
            "    ON p.claim_id = c.claim_id";
        
        // Split results into successful and failed enrichments
        
        // 1. Insert successful enrichments
        String successfulEnrichmentQuery = 
            "INSERT INTO enriched_payments_sink\n" +
            "SELECT \n" +
            "    payment_id, claim_id, payment_amount, payment_date, processor_id,\n" +
            "    payment_method, payment_status, reference_number, transaction_id,\n" +
            "    notes, created_by, member_id, claim_amount, claim_status,\n" +
            "    claim_created_date, enrichment_status, enrichment_timestamp\n" +
            "FROM (" + enrichmentQuery + ")\n" +
            "WHERE enrichment_status = 'SUCCESS'";
            
        LOG.info("Executing successful enrichment query: {}", successfulEnrichmentQuery);
        tableEnv.executeSql(successfulEnrichmentQuery);
        
        // 2. Insert failed enrichments
        String failedEnrichmentQuery = 
            "INSERT INTO failed_payments_sink\n" +
            "SELECT \n" +
            "    payment_id, claim_id, payment_amount, payment_date, processor_id,\n" +
            "    payment_method, payment_status, reference_number, transaction_id,\n" +
            "    notes, created_by, enrichment_status, enrichment_timestamp,\n" +
            "    CONCAT('Claim not found: ', claim_id) as error_message\n" +
            "FROM (" + enrichmentQuery + ")\n" +
            "WHERE enrichment_status = 'CLAIM_NOT_FOUND'";
            
        LOG.info("Executing failed enrichment query: {}", failedEnrichmentQuery);
        tableEnv.executeSql(failedEnrichmentQuery);
        
        LOG.info("Enrichment pipeline configured successfully");
    }
    
    /**
     * Utility method to get environment variable with default value
     */
    private static String getEnvOrDefault(String key, String defaultValue) {
        String value = System.getenv(key);
        return (value != null && !value.trim().isEmpty()) ? value : defaultValue;
    }
}
