package rental.demo.table;

import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import static org.apache.flink.table.api.Expressions.$;
import static org.apache.flink.table.api.Expressions.row;
import static org.apache.flink.table.api.Expressions.withAllColumns;

/*
 * Process raw-jobs topic using Flink Table API
 */
public class RentalEventsProcessing {
    
    private static final Logger LOG = LoggerFactory.getLogger(RentalEventsProcessing.class);
 

    public static void main(String[] args) {
        String kafkaBootstrapServers = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String consumerGroup = System.getenv().getOrDefault("CONSUMER_GROUP", "raw-jobs-consumer");
        String jobTopic = System.getenv().getOrDefault("RAW_JOBS_TOPIC", "raw-jobs");
        String orderTopic = System.getenv().getOrDefault("RAW_ORDERS_TOPIC", "raw-orders");
        String orderDetailsTopic = System.getenv().getOrDefault("ORDER_DETAILS_TOPIC", "order-details");
        
        String catalogName = System.getenv().getOrDefault("CATALOG_NAME", "rental");
        String catalogDatabaseName = System.getenv().getOrDefault("CATALOG_DATABASE_NAME", "rentaldb");
    
        LOG.info("Starting Raw Job Processing Job");
        LOG.info("Kafka Bootstrap Servers: {}", kafkaBootstrapServers);
        LOG.info("Consumer Group: {}", consumerGroup);
        LOG.info("Job Topic: {}", jobTopic);
        LOG.info("Order Topic: {}", orderTopic);
        LOG.info("Order Details Topic: {}", orderDetailsTopic);
        
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        EnvironmentSettings settings = EnvironmentSettings
            .newInstance()
            .inStreamingMode()
            .build();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env, settings);
        if (tableEnv == null) {
            throw new NullPointerException("Table environment cannot be null");
        }
        // following not yet supported
        //tableEnv.useCatalog(catalogName);
        //tableEnv.useDatabase(catalogDatabaseName);

        createSourceTable(tableEnv, catalogName, catalogDatabaseName, orderTopic, kafkaBootstrapServers, consumerGroup);
        createSourceTable(tableEnv, catalogName, catalogDatabaseName, jobTopic, kafkaBootstrapServers, consumerGroup);

        // Create destination table for deduplicated products
        createSinkTable(tableEnv, catalogName, catalogDatabaseName, outputTopic, kafkaBootstrapServers);
   
        tableEnv.from(orderTopic).select(withAllColumns()).execute().print();
    }
    
     /**
     * Creates the source table reading from Kafka products topic
     */
    public static void createSourceTable(StreamTableEnvironment tableEnv, 
                                        String catalogName,
                                        String catalogDatabaseName,
                                        String tableName, 
                                        String kafkaBootstrapServers,
                                        String consumerGroup) {
        // Input validation
  
        if (tableName == null) {
            throw new NullPointerException("Table name cannot be null");
        }
        if (kafkaBootstrapServers == null || kafkaBootstrapServers.trim().isEmpty()) {
            throw new IllegalArgumentException("Kafka bootstrap servers cannot be null or empty");
        }
        if (consumerGroup == null || consumerGroup.trim().isEmpty()) {
            throw new IllegalArgumentException("Consumer group cannot be null or empty");
        }
        String sourceTableDDL = "";
        if (tableName.equals("raw_jobs")) {
            sourceTableDDL = EventModels.CREATE_RAW_JOB_TABLE;
        } else if (tableName.equals("raw_orders")) {
            sourceTableDDL = EventModels.CREATE_RAW_ORDER_TABLE;
        } else {
            throw new IllegalArgumentException("Invalid table name: " + tableName);
        }
        sourceTableDDL = String.format(sourceTableDDL, catalogName, catalogDatabaseName, tableName, tableName, kafkaBootstrapServers, consumerGroup);
        
        LOG.info("Creating source table: {}", sourceTableDDL);
        System.out.println(sourceTableDDL);
        tableEnv.executeSql(sourceTableDDL);
                                    
    }

    public static void createSinkTable(StreamTableEnvironment tableEnv, 
                                        String catalogName,
                                        String catalogDatabaseName,
                                        String tableName, 
                                        String kafkaBootstrapServers) {
    
        String sinkTableDDL = "";
        if (table_name == "order-details") {
            sinkTableDDL = EventModels.CREATE_ORDER_DETAILS_TABLE;
        } else {
            throw new IllegalArgumentException("Invalid table name: " + tableName);
        }
                                    
        sinkTableDDL = String.format(sinkTableDDL, catalogName, catalogDatabaseName, tableName, tableName, kafkaBootstrapServers);
        LOG.info("Creating sink table: {}", sinkTableDDL);
        System.out.println(sinkTableDDL);
        tableEnv.executeSql(sinkTableDDL);
    }
} // end of class
