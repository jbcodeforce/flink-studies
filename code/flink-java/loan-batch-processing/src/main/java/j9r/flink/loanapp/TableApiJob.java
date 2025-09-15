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
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.types.RowKind;

import java.io.PrintWriter;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Table API job for analyzing fraudulent loan applications
 * Uses Flink Table API for SQL-like fraud analysis queries
 */
public class TableApiJob {

    public static void main(String[] args) throws Exception {
        // Set up the streaming execution environment using the Table API
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        final StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

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

        // Create a Table from the DataStream
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

        // SQL Query 1: Total number of fraudulent applications
        Table fraudCountTable = tableEnv.sqlQuery(
            "SELECT COUNT(*) as total_fraudulent_loans " +
            "FROM loan_applications " +
            "WHERE fraudFlag = 1"
        );

        // SQL Query 2: Fraud breakdown by loan type
        Table fraudByTypeTable = tableEnv.sqlQuery(
            "SELECT loanType, COUNT(*) as fraudulent_count " +
            "FROM loan_applications " +
            "WHERE fraudFlag = 1 " +
            "GROUP BY loanType " +
            "ORDER BY fraudulent_count DESC"
        );

        // SQL Query 3: Fraud breakdown by fraud type (when specified)
        Table fraudByTypeClassificationTable = tableEnv.sqlQuery(
            "SELECT fraudType, COUNT(*) as fraud_count " +
            "FROM loan_applications " +
            "WHERE fraudFlag = 1 AND fraudType IS NOT NULL AND fraudType <> '' " +
            "GROUP BY fraudType " +
            "ORDER BY fraud_count DESC"
        );

        // SQL Query 4: Fraud rate by loan status
        Table fraudRateByStatusTable = tableEnv.sqlQuery(
            "SELECT loanStatus, " +
            "       COUNT(*) as total_applications, " +
            "       SUM(fraudFlag) as fraudulent_applications, " +
            "       ROUND(CAST(SUM(fraudFlag) AS DOUBLE) / COUNT(*) * 100, 2) as fraud_rate_percent " +
            "FROM loan_applications " +
            "GROUP BY loanStatus " +
            "ORDER BY fraud_rate_percent DESC"
        );

        // SQL Query 5: Average loan amount for fraudulent vs non-fraudulent applications
        Table fraudAmountAnalysisTable = tableEnv.sqlQuery(
            "SELECT " +
            "  CASE WHEN fraudFlag = 1 THEN 'Fraudulent' ELSE 'Legitimate' END as application_type, " +
            "  COUNT(*) as application_count, " +
            "  ROUND(AVG(loanAmountRequested), 2) as avg_loan_amount, " +
            "  ROUND(AVG(monthlyIncome), 2) as avg_monthly_income " +
            "FROM loan_applications " +
            "GROUP BY fraudFlag " +
            "ORDER BY fraudFlag DESC"
        );

        // Convert Table results back to DataStream for output
        // For simple aggregation without GROUP BY - use toDataStream
        DataStream<org.apache.flink.types.Row> fraudCountStream = tableEnv.toDataStream(fraudCountTable);
        
        // For GROUP BY aggregations - use toChangelogStream to handle upserts properly
        DataStream<org.apache.flink.types.Row> fraudByTypeStream = tableEnv.toChangelogStream(fraudByTypeTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
            
        DataStream<org.apache.flink.types.Row> fraudTypeClassificationStream = tableEnv.toChangelogStream(fraudByTypeClassificationTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
            
        DataStream<org.apache.flink.types.Row> fraudRateStream = tableEnv.toChangelogStream(fraudRateByStatusTable)
            .filter(row -> row.getKind().equals(org.apache.flink.types.RowKind.INSERT) || 
                          row.getKind().equals(org.apache.flink.types.RowKind.UPDATE_AFTER));
            
        DataStream<org.apache.flink.types.Row> fraudAmountAnalysisStream = tableEnv.toChangelogStream(fraudAmountAnalysisTable)
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

        fraudByTypeStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("Fraud by Loan Type - %s: %s applications", 
                    row.getField(0), row.getField(1));
            }
        }).print("FRAUD_BY_TYPE").setParallelism(1);

        fraudTypeClassificationStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("Fraud Classification - %s: %s cases", 
                    row.getField(0), row.getField(1));
            }
        }).print("FRAUD_CLASSIFICATION").setParallelism(1);

        fraudRateStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("Loan Status %s: %s total, %s fraudulent (%.2f%% fraud rate)", 
                    row.getField(0), row.getField(1), row.getField(2), row.getField(3));
            }
        }).print("FRAUD_RATE").setParallelism(1);

        fraudAmountAnalysisStream.map(new MapFunction<org.apache.flink.types.Row, String>() {
            @Override
            public String map(org.apache.flink.types.Row row) throws Exception {
                return String.format("%s Applications: Count=%s, Avg Loan=$%.2f, Avg Income=$%.2f", 
                    row.getField(0), row.getField(1), row.getField(2), row.getField(3));
            }
        }).print("FRAUD_ANALYSIS").setParallelism(1);

        // Write fraud analysis results to CSV file
        DataStream<String> csvOutput = fraudCountStream
            .union(fraudByTypeStream, fraudTypeClassificationStream, fraudRateStream, fraudAmountAnalysisStream)
            .map(new MapFunction<org.apache.flink.types.Row, String>() {
                @Override
                public String map(org.apache.flink.types.Row row) throws Exception {
                    // Convert row to CSV format
                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < row.getArity(); i++) {
                        if (i > 0) sb.append(",");
                        Object field = row.getField(i);
                        sb.append(field != null ? field.toString() : "");
                    }
                    return sb.toString();
                }
            });

        csvOutput.addSink(new SinkFunction<String>() {
            private PrintWriter writer;
            private boolean headerWritten = false;

            @Override
            public void invoke(String value, Context context) throws Exception {
                if (writer == null) {
                    writer = new PrintWriter(new FileWriter("/tmp/fraud_analysis_results.csv", false));
                    if (!headerWritten) {
                        writer.println("analysis_type,metric,value");
                        headerWritten = true;
                    }
                }
                
                writer.println(value);
                writer.flush();
                System.out.println("Written fraud analysis to CSV: " + value);
            }

            @Override
            public void finish() throws Exception {
                if (writer != null) {
                    writer.close();
                    System.out.println("Fraud analysis results written to: /tmp/fraud_analysis_results.csv");
                }
            }
        }).setParallelism(1);

        // Execute the job
        env.execute("Fraud Analysis - Table API Job");
    }
}
