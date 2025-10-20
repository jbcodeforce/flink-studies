package rental.demo.table;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.ValidationException;
import org.apache.flink.table.catalog.Catalog;
import org.apache.flink.table.catalog.CatalogBaseTable;
import org.apache.flink.table.catalog.CatalogDatabase;
import org.apache.flink.table.catalog.CatalogDatabaseImpl;
import org.apache.flink.table.catalog.GenericInMemoryCatalog;
import org.apache.flink.table.catalog.ObjectPath;
import org.apache.flink.table.catalog.exceptions.TableNotExistException;
import org.apache.flink.table.catalog.exceptions.DatabaseNotExistException;
import org.apache.flink.table.catalog.exceptions.DatabaseAlreadyExistException;

import java.util.HashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

import rental.demo.table.RentalEventsProcessing;
/**
 * Unit tests for RentalEventsProcessing class
 */
public class RentalEventsProcessingTest {
    private static final Logger logger = LoggerFactory.getLogger(RentalEventsProcessingTest.class);
    private StreamTableEnvironment tableEnv;
    private static final String CATALOG_NAME = "test_catalog";
    private static final String DATABASE_NAME = "test_db";
    private static final String KAFKA_SERVERS = "localhost:9092";
    private static final String CONSUMER_GROUP = "test-consumer";

    @BeforeEach
    void setUp() throws Exception {
        try {
            // Create execution environment
            StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
            EnvironmentSettings settings = EnvironmentSettings
                .newInstance()
                .inStreamingMode()
                .build();
            tableEnv = StreamTableEnvironment.create(env, settings);

            // Create and register test catalog with default database
            GenericInMemoryCatalog catalog = new GenericInMemoryCatalog(CATALOG_NAME, DATABASE_NAME);
            
            // Create database properties
            HashMap<String, String> props = new HashMap<>();
            props.put("comment", "Test database for unit tests");
            CatalogDatabase testDb = new CatalogDatabaseImpl(props, "Test database for unit tests");
            
            // Register catalog and create database
            tableEnv.registerCatalog(CATALOG_NAME, catalog);
            if (!catalog.databaseExists(DATABASE_NAME)) {
                catalog.createDatabase(DATABASE_NAME, testDb, true);
            }
            
            // Use the test catalog and database
            tableEnv.useCatalog(CATALOG_NAME);
            tableEnv.useDatabase(DATABASE_NAME);
        } catch (DatabaseAlreadyExistException e) {
            // Database already exists, which is fine for our tests
            logger.info("Database already exists: " + DATABASE_NAME);
        } catch (Exception e) {
            logger.error("Error setting up test catalog", e);
            throw e;
        }
    }

    @Test
    @DisplayName("Test creating raw_jobs source table")
    void testCreateRawJobsSourceTable() {
        // When
        RentalEventsProcessing.createSourceTable(
            tableEnv, 
            CATALOG_NAME,
            DATABASE_NAME,
            "raw_jobs", 
            KAFKA_SERVERS, 
            CONSUMER_GROUP
        );

        // Then
        try {
            ObjectPath tablePath = new ObjectPath(DATABASE_NAME, "raw_jobs");
            CatalogBaseTable table = tableEnv.getCatalog(CATALOG_NAME).get().getTable(tablePath);
            assertNotNull(table, "Table should be created");
            
            // Verify table schema
            String[] expectedColumns = {
                "job_id", "job_type", "job_status", "rate_service_provider", 
                "total_paid", "job_date_start", "job_completed_date", 
                "job_entered_date", "job_last_modified_date", "service_provider_name"
            };
            
            for (String column : expectedColumns) {
                assertTrue(table.getSchema().getFieldNames().length > 0, 
                    "Table should have fields");
                assertTrue(
                    java.util.Arrays.asList(table.getSchema().getFieldNames()).contains(column),
                    "Table should contain column: " + column
                );
            }
        } catch (TableNotExistException e) {
            fail("Table should exist", e);
        }
    }

    @Test
    @DisplayName("Test creating raw_orders source table")
    void testCreateRawOrdersSourceTable() {
        // When
        RentalEventsProcessing.createSourceTable(
            tableEnv, 
            CATALOG_NAME,
            DATABASE_NAME,
            "raw_orders", 
            KAFKA_SERVERS, 
            CONSUMER_GROUP
        );

        // Then
        try {
            ObjectPath tablePath = new ObjectPath(DATABASE_NAME, "raw_orders");
            CatalogBaseTable table = tableEnv.getCatalog(CATALOG_NAME).get().getTable(tablePath);
            assertNotNull(table, "Table should be created");
            
            // Verify table schema
            String[] expectedColumns = {
                "OrderId", "Status", "Equipment", "TotalPaid", "Type", 
                "Coverage", "Itinerary", "OrderType", "AssociatedContractId"
            };
            
            for (String column : expectedColumns) {
                assertTrue(table.getSchema().getFieldNames().length > 0, 
                    "Table should have fields");
                assertTrue(
                    java.util.Arrays.asList(table.getSchema().getFieldNames()).contains(column),
                    "Table should contain column: " + column
                );
            }
        } catch (TableNotExistException e) {
            fail("Table should exist", e);
        }
    }

    @Test
    @DisplayName("Test creating source table with invalid table name")
    void testCreateSourceTableWithInvalidName() {
        // When/Then
        assertThrows(IllegalArgumentException.class, () -> {
            RentalEventsProcessing.createSourceTable(
                tableEnv, 
                CATALOG_NAME,
                DATABASE_NAME,
                "invalid_table", 
                KAFKA_SERVERS, 
                CONSUMER_GROUP
            );
        }, "Should throw IllegalArgumentException for invalid table name");
    }

    @Test
    @DisplayName("Test creating source table with null parameters")
    void testCreateSourceTableWithNullParams() {
        // Test null table environment
        assertThrows(NullPointerException.class, () -> {
            RentalEventsProcessing.createSourceTable(
                null, 
                CATALOG_NAME,
                DATABASE_NAME,
                "raw_jobs", 
                KAFKA_SERVERS, 
                CONSUMER_GROUP
            );
        }, "Should throw NullPointerException for null table environment");

        // Test null table name
        assertThrows(NullPointerException.class, () -> {
            RentalEventsProcessing.createSourceTable(
                tableEnv, 
                CATALOG_NAME,
                DATABASE_NAME,
                null, 
                KAFKA_SERVERS, 
                CONSUMER_GROUP
            );
        }, "Should throw NullPointerException for null table name");

        // Test null Kafka servers
        assertThrows(IllegalArgumentException.class, () -> {
            RentalEventsProcessing.createSourceTable(
                tableEnv, 
                CATALOG_NAME,
                DATABASE_NAME,
                "raw_jobs", 
                null, 
                CONSUMER_GROUP
            );
        }, "Should throw IllegalArgumentException for null Kafka servers");

        // Test null consumer group
        assertThrows(IllegalArgumentException.class, () -> {
            RentalEventsProcessing.createSourceTable(
                tableEnv, 
                CATALOG_NAME,
                DATABASE_NAME,
                "raw_jobs", 
                KAFKA_SERVERS, 
                null
            );
        }, "Should throw IllegalArgumentException for null consumer group");
    }
}
