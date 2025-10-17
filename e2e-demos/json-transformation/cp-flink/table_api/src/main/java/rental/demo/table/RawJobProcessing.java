package rental.demo.table;

import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.api.java.utils.ParameterTool;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
/*
 * Process raw-jobs topic using Flink Table API
 */
public class RawJobProcessing {
    
    private static final Logger LOG = LoggerFactory.getLogger(RawJobProcessing.class);
 

    public static void main(String[] args) {
        String kafkaBootstrapServers = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String consumerGroup = System.getenv().getOrDefault("CONSUMER_GROUP", "raw-jobs-consumer");
        String inputTopic = System.getenv().getOrDefault("INPUT_TOPIC", "raw-jobs");
        String outputTopic = System.getenv().getOrDefault("OUTPUT_TOPIC", "deduplicated-jobs");
        String tableName = inputTopic;
    
        LOG.info("Starting Raw Job Processing Job");
        LOG.info("Kafka Bootstrap Servers: {}", kafkaBootstrapServers);
        LOG.info("Consumer Group: {}", consumerGroup);
        LOG.info("Input Topic: {}", inputTopic);
        LOG.info("Output Topic: {}", outputTopic);
        LOG.info("Table Name: {}", tableName);
        
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        EnvironmentSettings settings = EnvironmentSettings
            .newInstance()
            .inStreamingMode()
            .build();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env, settings);
        env.enableCheckpointing(30000); // checkpoint every 30 seconds
       
        createSourceTable(tableEnv, tableName, inputTopic, kafkaBootstrapServers, consumerGroup);

        // Create destination table for deduplicated products
       //  createSinkTable(tableEnv, outputTopic, kafkaBootstrapServers);
        // Example 1: Simple SELECT
        Table rawJobs = tableEnv.from(tableName);
        Table result = rawJobs.sqlQuery("SELECT * FROM " + tableName);
        TableResult tableResult = result.execute();
        tableResult.print();
    }
    
     /**
     * Creates the source table reading from Kafka products topic
     */
    private static void createSourceTable(StreamTableEnvironment tableEnv, 
                                        String tableName,
                                        String inputTopic, 
                                        String kafkaBootstrapServers,
                                        String consumerGroup) {
        String sourceTableDDL = String.format(
            "CREATE TABLE %s (" +
            "    job_id BIGINT,",
            "    job_type STRING,",
            "    job_status STRING,",
            "    rate_service_provider STRING,",
            "    total_paid DECIMAL(10,2),",
            "    job_date_start TIMESTAMP(3),",
            "    job_completed_date TIMESTAMP(3),",
            "    job_entered_date TIMESTAMP(3),",
            "    job_last_modified_date TIMESTAMP(3),",
            "    service_provider_name STRING,",
            "    WATERMARK FOR job_last_modified_date AS job_last_modified_date - INTERVAL '5' SECOND",
            ") WITH (",
            "  'connector' = 'kafka'," +
            "  'topic' = '%s'," +
            "  'properties.bootstrap.servers' = '%s'," +
            "  'properties.group.id' = '%s'," +
            "  'scan.startup.mode' = 'earliest-offset'," +
            "  'format' = 'json'," +
            "  'json.fail-on-missing-field' = 'false'," +
            "  'json.ignore-parse-errors' = 'true'" +
            ")", tableName, inputTopic, kafkaBootstrapServers, consumerGroup);
        
        LOG.info("Creating source table: {}", sourceTableDDL);
        tableEnv.executeSql(sourceTableDDL);
                                    
    }
} // end of class
