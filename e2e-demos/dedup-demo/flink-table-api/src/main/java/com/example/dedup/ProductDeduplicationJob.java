package com.jbcodeforce.dedup;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.table.expressions.Expression;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.apache.flink.table.api.Expressions.*;

/**
 * Flink Table API implementation for product event deduplication.
 * 
 * This job:
 * 1. Reads product events from Kafka topic 'products'
 * 2. Flattens the nested product structure
 * 3. Deduplicates events based on product content
 * 4. Writes deduplicated results to 'src_products' topic
 */
public class ProductDeduplicationJob {
    
    private static final Logger LOG = LoggerFactory.getLogger(ProductDeduplicationJob.class);
    
    public static void main(String[] args) throws Exception {
        
        // Parse command line arguments
        String kafkaBootstrapServers = getParam(args, "kafka.bootstrap.servers", "localhost:9092");
        String inputTopic = getParam(args, "input.topic", "products");
        String outputTopic = getParam(args, "output.topic", "src_products");
        String consumerGroup = getParam(args, "consumer.group", "flink-dedup-consumer");
        
        LOG.info("Starting Product Deduplication Job");
        LOG.info("Kafka Bootstrap Servers: {}", kafkaBootstrapServers);
        LOG.info("Input Topic: {}", inputTopic);
        LOG.info("Output Topic: {}", outputTopic);
        LOG.info("Consumer Group: {}", consumerGroup);
        
        // Set up the execution environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        EnvironmentSettings settings = EnvironmentSettings
            .newInstance()
            .inStreamingMode()
            .build();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env, settings);
        
        // Configure checkpointing for fault tolerance
        env.enableCheckpointing(30000); // checkpoint every 30 seconds
        
        // Create source table for Kafka product events
        createSourceTable(tableEnv, inputTopic, kafkaBootstrapServers, consumerGroup);
        
        // Create destination table for deduplicated products
        createSinkTable(tableEnv, outputTopic, kafkaBootstrapServers);
        
        // Implement deduplication logic
        Table deduplicatedProducts = performDeduplication(tableEnv);
        
        // Insert deduplicated data into sink table
        deduplicatedProducts.executeInsert("src_products");
        
        LOG.info("Product Deduplication Job submitted successfully");
    }
    
    /**
     * Creates the source table reading from Kafka products topic
     */
    private static void createSourceTable(StreamTableEnvironment tableEnv, 
                                        String inputTopic, 
                                        String kafkaBootstrapServers,
                                        String consumerGroup) {
        
        String sourceTableDDL = String.format(
            "CREATE TABLE product_events_raw (" +
            "  event_id STRING," +
            "  action STRING," +
            "  `timestamp` TIMESTAMP(3)," +
            "  processed BOOLEAN," +
            "  product ROW<" +
            "    product_id INT," +
            "    product_name STRING," +
            "    description STRING," +
            "    price DECIMAL(10,2)," +
            "    stock_quantity INT," +
            "    discount DECIMAL(10,2)," +
            "    created_at TIMESTAMP(3)," +
            "    updated_at TIMESTAMP(3)" +
            "  >," +
            "  old_price DECIMAL(10,2)," +
            "  WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND" +
            ") WITH (" +
            "  'connector' = 'kafka'," +
            "  'topic' = '%s'," +
            "  'properties.bootstrap.servers' = '%s'," +
            "  'properties.group.id' = '%s'," +
            "  'scan.startup.mode' = 'earliest-offset'," +
            "  'format' = 'json'," +
            "  'json.timestamp-format.standard' = 'ISO-8601'," +
            "  'json.fail-on-missing-field' = 'false'," +
            "  'json.ignore-parse-errors' = 'true'" +
            ")", inputTopic, kafkaBootstrapServers, consumerGroup);
        
        LOG.info("Creating source table: {}", sourceTableDDL);
        tableEnv.executeSql(sourceTableDDL);
    }
    
    /**
     * Creates the sink table for deduplicated products
     */
    private static void createSinkTable(StreamTableEnvironment tableEnv, 
                                      String outputTopic, 
                                      String kafkaBootstrapServers) {
        
        String sinkTableDDL = String.format(
            "CREATE TABLE src_products (" +
            "  product_id INT," +
            "  product_name STRING," +
            "  description STRING," +
            "  price DECIMAL(10,2)," +
            "  stock_quantity INT," +
            "  discount DECIMAL(10,2)," +
            "  created_at TIMESTAMP(3)," +
            "  updated_at TIMESTAMP(3)," +
            "  last_event_id STRING," +
            "  last_action STRING," +
            "  last_event_timestamp TIMESTAMP(3)," +
            "  last_old_price DECIMAL(10,2)," +
            "  processing_time TIMESTAMP(3)," +
            "  PRIMARY KEY (product_id) NOT ENFORCED" +
            ") WITH (" +
            "  'connector' = 'upsert-kafka'," +
            "  'topic' = '%s'," +
            "  'properties.bootstrap.servers' = '%s'," +
            "  'key.format' = 'json'," +
            "  'value.format' = 'json'," +
            "  'value.json.timestamp-format.standard' = 'ISO-8601'" +
            ")", outputTopic, kafkaBootstrapServers);
        
        LOG.info("Creating sink table: {}", sinkTableDDL);
        tableEnv.executeSql(sinkTableDDL);
    }
    
    /**
     * Implements the deduplication logic using Table API
     */
    private static Table performDeduplication(StreamTableEnvironment tableEnv) {
        
        // Get the source table
        Table rawEvents = tableEnv.from("product_events_raw");
        
        // Flatten the nested product structure
        Table flattenedEvents = rawEvents
            .select(
                $("event_id"),
                $("action"),
                $("timestamp").as("event_timestamp"),
                $("processed"),
                $("product").get("product_id").as("product_id"),
                $("product").get("product_name").as("product_name"),
                $("product").get("description").as("description"),
                $("product").get("price").as("price"),
                $("product").get("stock_quantity").as("stock_quantity"),
                $("product").get("discount").as("discount"),
                $("product").get("created_at").as("created_at"),
                $("product").get("updated_at").as("updated_at"),
                $("old_price"),
                $("PROCTIME").as("processing_time")
            )
            .filter($("product_id").isNotNull()); // Filter out malformed events
        
        LOG.info("Created flattened events table");
        
        // Register the flattened table as a view for reuse
        tableEnv.createTemporaryView("product_events_flattened", flattenedEvents);
        
        // Implement deduplication using SQL (easier with complex window functions)
        String deduplicationSQL = 
            "SELECT " +
            "  product_id," +
            "  product_name," +
            "  description," +
            "  price," +
            "  stock_quantity," +
            "  discount," +
            "  created_at," +
            "  updated_at," +
            "  event_id as last_event_id," +
            "  action as last_action," +
            "  event_timestamp as last_event_timestamp," +
            "  old_price as last_old_price," +
            "  processing_time " +
            "FROM (" +
            "  SELECT *," +
            "    ROW_NUMBER() OVER (" +
            "      PARTITION BY product_id, product_name, description, price, stock_quantity, discount " +
            "      ORDER BY event_timestamp DESC" +
            "    ) as row_num " +
            "  FROM product_events_flattened" +
            ") ranked_events " +
            "WHERE row_num = 1";
        
        LOG.info("Executing deduplication query");
        Table deduplicatedEvents = tableEnv.sqlQuery(deduplicationSQL);
        
        return deduplicatedEvents;
    }
    
    /**
     * Helper method to parse command line parameters
     */
    private static String getParam(String[] args, String key, String defaultValue) {
        for (String arg : args) {
            if (arg.startsWith("--" + key + "=")) {
                return arg.substring(("--" + key + "=").length());
            }
        }
        return defaultValue;
    }
} 