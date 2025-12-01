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

        createSourceTable(tableEnv, catalogName, catalogDatabaseName, orderTopic);
        createSourceTable(tableEnv, catalogName, catalogDatabaseName, jobTopic);

        // Create destination table for deduplicated products
        createSinkTable(tableEnv, catalogName, catalogDatabaseName, orderDetailsTopic);
   
        // Create the transformation and join logic
        String insertSql = String.format(
            "INSERT INTO `%s` " +
            "SELECT " +
            "  o.OrderId, " +
            "  ARRAY[ROW( " +
            "    o.OrderId, " +
            "    o.Status, " +
            "    o.Equipment, " +
            "    o.TotalPaid, " +
            "    o.Type, " +
            "    o.Coverage.details, " +
            "    ROW( " +
            "      o.Itinerary.PickupDate, " +
            "      o.Itinerary.DropoffDate, " +
            "      o.Itinerary.PickupLocation, " +
            "      o.Itinerary.DropoffLocation " +
            "    ), " +
            "    o.OrderType, " +
            "    CAST(o.AssociatedContractId AS BIGINT) " +
            "  )], " +
            "  COALESCE(j.MovingHelpDetails, ARRAY[]) " +
            "FROM `%s` o " +
            "LEFT JOIN ( " +
            "  SELECT " +
            "    order_id, " +
            "    ARRAY_AGG(ROW( " +
            "      job_id, " +
            "      job_type, " +
            "      job_status, " +
            "      rate_service_provider, " +
            "      total_paid, " +
            "      job_date_start, " +
            "      job_completed_date, " +
            "      job_entered_date, " +
            "      job_last_modified_date, " +
            "      service_provider_name " +
            "    )) as MovingHelpDetails " +
            "  FROM `%s` " +
            "  GROUP BY order_id " +
            ") j ON o.OrderId = j.order_id",
            orderDetailsTopic, orderTopic, jobTopic
        );

        LOG.info("Executing insert statement: {}", insertSql);
        System.out.println(insertSql);
        tableEnv.executeSql(insertSql);
    }

    /**
     * Creates the source table reading from Kafka products topic
     */
    public static void createSourceTable(StreamTableEnvironment tableEnv, 
                                        String catalogName,
                                        String catalogDatabaseName,
                                        String tableName) {
        // Input validation
  
        if (tableName == null) {
            throw new NullPointerException("Table name cannot be null");
        }

        String sourceTableDDL = "";
        if (tableName.equals("raw_jobs")) {
            sourceTableDDL = EventModels.CREATE_RAW_JOB_TABLE;
        } else if (tableName.equals("raw_orders")) {
            sourceTableDDL = EventModels.CREATE_RAW_ORDER_TABLE;
        } else {
            throw new IllegalArgumentException("Invalid table name: " + tableName);
        }
        sourceTableDDL = String.format(sourceTableDDL, catalogName, catalogDatabaseName, tableName, tableName);
        
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
        if (tableName == "order-details") {
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
