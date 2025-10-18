package rental.demo.table;

import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.api.java.utils.ParameterTool;
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
        env.enableCheckpointing(30000); // checkpoint every 30 seconds
       
        createSourceTable(tableEnv, orderTopic, kafkaBootstrapServers, consumerGroup);
        createSourceTable(tableEnv, jobTopic, kafkaBootstrapServers, consumerGroup);

        // Create destination table for deduplicated products
       //  createSinkTable(tableEnv, outputTopic, kafkaBootstrapServers);
   
        tableEnv.from(orderTopic).select(withAllColumns()).execute().print();
    }
    
     /**
     * Creates the source table reading from Kafka products topic
     */
    private static void createSourceTable(StreamTableEnvironment tableEnv, 
                                        String inputTopic, 
                                        String kafkaBootstrapServers,
                                        String consumerGroup) {
        String sourceTableDDL = "";
        if (inputTopic.equals("raw_jobs")) {
            sourceTableDDL = EventModels.CREATE_RAW_JOB_TABLE;
        } else if (inputTopic.equals("raw_orders")) {
            sourceTableDDL = EventModels.CREATE_RAW_ORDER_TABLE;
        } else {
            throw new IllegalArgumentException("Invalid table name: " + inputTopic);
        }
        sourceTableDDL = String.format(sourceTableDDL, inputTopic, kafkaBootstrapServers, consumerGroup);
        
        LOG.info("Creating source table: {}", sourceTableDDL);
        tableEnv.executeSql(sourceTableDDL);
                                    
    }
} // end of class
