/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package j9r.flink.loanapp;

import org.apache.flink.api.common.functions.FilterFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.connector.file.src.FileSource;
import org.apache.flink.connector.file.src.reader.TextLineInputFormat;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.DataTypes;
import static org.apache.flink.table.api.Expressions.$;
import static org.apache.flink.table.api.Expressions.lit;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.types.RowKind;
import org.apache.flink.connector.jdbc.JdbcConnectionOptions;
import org.apache.flink.connector.jdbc.JdbcExecutionOptions;
import org.apache.flink.connector.jdbc.JdbcSink;
import org.apache.flink.connector.jdbc.JdbcStatementBuilder;

import java.io.PrintWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.DriverManager;

/**
 * Table API job for analyzing fraudulent loan applications
 * Uses Flink Table API for SQL-like fraud analysis queries
 */
public class FraudCountTableApiJob {

    public static void debug_fraud_distribution(StreamTableEnvironment tableEnv, Table fraudDistributionTable) {
        // Debug: Print fraud flag distribution
        DataStream<org.apache.flink.types.Row> fraudDistributionStream = tableEnv.toChangelogStream(fraudDistributionTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
                          
        fraudDistributionStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("Fraud Flag Distribution: Flag=%s, Count=%s", 
                    row.getField(0), row.getField(1));
            }
        }).print("FRAUD_DISTRIBUTION").setParallelism(1);
    }

    public static void debug_total_count(StreamTableEnvironment tableEnv, Table totalCountTable) {
        // Debug: Print total record count
        DataStream<org.apache.flink.types.Row> totalCountStream = tableEnv.toChangelogStream(totalCountTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
                          
        totalCountStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return "Total Records Loaded: " + row.getField(0);
            }
        }).print("TOTAL_COUNT").setParallelism(1);
    }

    public static void main(String[] args) throws Exception {
        // Set up the streaming execution environment using the Table API
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        final StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

        // DuckDB connection settings
        String duckdbPath = "/tmp/fraud_analysis.db";
        String jdbcUrl = "jdbc:duckdb:" + duckdbPath;
        
        System.out.println("Using DuckDB database at: " + duckdbPath);
        
        // Create the physical table in DuckDB first
        try (java.sql.Connection conn = java.sql.DriverManager.getConnection(jdbcUrl);
             java.sql.Statement stmt = conn.createStatement()) {
            
            // Drop table if exists (for clean reruns)
            stmt.execute("DROP TABLE IF EXISTS fraud_analysis");
            
            // Create the physical table in DuckDB
            stmt.execute(
                "CREATE TABLE fraud_analysis (" +
                "  analysis_date DATE, " +
                "  analysis_type VARCHAR, " +
                "  analysis_timestamp TIMESTAMP, " +
                "  total_fraudulent_loans BIGINT, " +
                "  PRIMARY KEY (analysis_date, analysis_type)" +
                ")"
            );
            
            System.out.println("Created physical table 'fraud_analysis' in DuckDB");
            
        } catch (Exception e) {
            System.err.println("Error creating DuckDB table: " + e.getMessage());
            throw new RuntimeException(e);
        }

        // Path to the CSV file
        String inputPath = "/Users/jerome/Documents/Code/flink-studies/e2e-demos/cdc-demo/datasets/loan_applications.csv";

        // Create a file source to read the CSV file
        FileSource<String> source = FileSource.forRecordStreamFormat(
                new TextLineInputFormat(),
                new Path(inputPath))
            .build();

        // Read the CSV file as a data stream
        DataStream<String> csvLines = env.fromSource(source, 
            org.apache.flink.api.common.eventtime.WatermarkStrategy.noWatermarks(), "file-source");

        // Parse CSV lines to LoanApplication objects (skip header)
        DataStream<LoanApplication> loanApplications = csvLines
            .filter(new FilterFunction<String>() {
                @Override
                public boolean filter(String line) throws Exception {
                    // Skip header line and empty lines
                    return !line.startsWith("application_id") && !line.trim().isEmpty();
                }
            })
            .map(new MapFunction<String, LoanApplication>() {
                @Override
                public LoanApplication map(String csvLine) throws Exception {
                    return LoanApplication.fromCsvLine(csvLine);
                }
            })
            .filter(new FilterFunction<LoanApplication>() {
                @Override
                public boolean filter(LoanApplication app) throws Exception {
                    // Filter out null records (parsing errors)
                    return app != null;
                }
            });

        // Create a Table from the DataStream to be used as temporary view
        Schema schema = Schema.newBuilder()
            .column("applicationId", DataTypes.STRING())
            .column("customerId", DataTypes.STRING())
            .column("applicationDate", DataTypes.STRING())
            .column("loanType", DataTypes.STRING())
            .column("loanAmountRequested", DataTypes.DOUBLE())
            .column("loanTenureMonths", DataTypes.INT())
            .column("interestRateOffered", DataTypes.DOUBLE())
            .column("purposeOfLoan", DataTypes.STRING())
            .column("employmentStatus", DataTypes.STRING())
            .column("monthlyIncome", DataTypes.DOUBLE())
            .column("cibilScore", DataTypes.INT())
            .column("existingEmisMonthly", DataTypes.DOUBLE())
            .column("debtToIncomeRatio", DataTypes.DOUBLE())
            .column("propertyOwnershipStatus", DataTypes.STRING())
            .column("residentialAddress", DataTypes.STRING())
            .column("applicantAge", DataTypes.INT())
            .column("gender", DataTypes.STRING())
            .column("numberOfDependents", DataTypes.INT())
            .column("loanStatus", DataTypes.STRING())
            .column("fraudFlag", DataTypes.INT())
            .column("fraudType", DataTypes.STRING())
            .build();

        Table loanTable = tableEnv.fromDataStream(loanApplications, schema);
        tableEnv.createTemporaryView("loan_applications", loanTable);

        
        // Check fraud records
        Table fraudCountTable = tableEnv.sqlQuery(
            "SELECT COUNT(*) as total_fraudulent_loans " +
            "FROM loan_applications " +
            "WHERE fraudFlag = 1"
        );
        

        // First option is to convert Table results back to DataStream for output, taking into account the changelog mode.
        DataStream<org.apache.flink.types.Row> fraudCountStream = tableEnv.toChangelogStream(fraudCountTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));

        // Print results to console
        System.out.println("=== FRAUD ANALYSIS RESULTS ===");
        
        fraudCountStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return "Total Fraudulent Loans: " + row.getField(0);
            }
        }).print("FRAUD_COUNT").setParallelism(1);

        
        // 2nd Option: Create DuckDB table using DDL SQL with upsert configuration
        tableEnv.executeSql(
            "CREATE TABLE fraud_analysis_sink (" +
            "  analysis_date DATE, " +
            "  analysis_type STRING, " +
            "  analysis_timestamp TIMESTAMP(3), " +
            "  total_fraudulent_loans BIGINT, " +
            "  PRIMARY KEY (analysis_date, analysis_type) NOT ENFORCED " +
            ") WITH (" +
            "  'connector' = 'jdbc', " +
            "  'url' = '" + jdbcUrl + "', " +
            "  'table-name' = 'fraud_analysis', " +
            "  'driver' = 'org.duckdb.DuckDBDriver', " +
            "  'sink.buffer-flush.max-rows' = '100', " +
            "  'sink.buffer-flush.interval' = '1s', " +
            "  'sink.max-retries' = '3' " +
            ")"
        );

        // Convert fraud count table to enriched table directly using Table API       
        Table enrichedTable = fraudCountTable.select(
            lit(java.time.LocalDate.now().toString()).cast(DataTypes.DATE()).as("analysis_date"),
            lit("fraud_count_analysis").as("analysis_type"),
            lit(new java.sql.Timestamp(System.currentTimeMillis())).as("analysis_timestamp"),
            $("total_fraudulent_loans")
        );
        
        // Debug: Print enriched table data before insertion
        System.out.println("=== ENRICHED TABLE DEBUG ===");
        DataStream<org.apache.flink.types.Row> debugEnrichedStream = tableEnv.toChangelogStream(enrichedTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
                          
        debugEnrichedStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("DEBUG Enriched Data: Date=%s, Type=%s, Timestamp=%s, Count=%s", 
                    row.getField(0), row.getField(1), row.getField(2), row.getField(3));
            }
        }).print("DEBUG_ENRICHED").setParallelism(1);
        
        // Insert fraud count into DuckDB
        System.out.println("Attempting to insert fraud count into DuckDB...");
        enrichedTable.insertInto("fraud_analysis_sink");

        // Also keep console output for monitoring by converting back to DataStream using changelog
        DataStream<org.apache.flink.types.Row> monitoringStream = tableEnv.toChangelogStream(enrichedTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
                          
        monitoringStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("Upserted to DuckDB - Date: %s, Type: %s, Timestamp: %s, Fraudulent Loans: %s", 
                    row.getField(0), row.getField(1), row.getField(2), row.getField(3));
            }
        }).print("DUCKDB_UPSERTS").setParallelism(1);

        // Execute the job
        env.execute("Fraud Analysis - DuckDB Table API Job");
        System.out.println("Fraud analysis results written to DuckDB: " + duckdbPath);
    }
}
