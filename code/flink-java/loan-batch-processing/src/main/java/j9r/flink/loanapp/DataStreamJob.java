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
import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.connector.file.src.FileSource;
import org.apache.flink.connector.file.src.reader.TextLineInputFormat;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;

import java.io.PrintWriter;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Batch processing of loan applications
 * Read a csv file and compute aggregates using Java DataStream
 */
public class DataStreamJob {

	public static void main(String[] args) throws Exception {
		// Sets up the execution environment, which is the main entry point
		// to building Flink applications.
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

		// Path to the CSV file - update this path as needed
		String inputPath = "/Users/jerome/Documents/Code/flink-studies/e2e-demos/cdc-demo/datasets/loan_applications.csv";
		String outputPath = "/tmp/loan_statistics_output";

		// Create a file source to read the CSV file
		FileSource<String> source = FileSource.forRecordStreamFormat(
				new TextLineInputFormat(),
				new Path(inputPath))
			.build();

		// Read the CSV file as a data stream
		DataStream<String> csvLines = env.fromSource(source, org.apache.flink.api.common.eventtime.WatermarkStrategy.noWatermarks(), "file-source");

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

		// Print sample records to console
		loanApplications.map(new MapFunction<LoanApplication, String>() {
			@Override
			public String map(LoanApplication app) throws Exception {
				return "Sample Record: " + app.toString();
			}
		}).print("SAMPLE_RECORDS").setParallelism(1);

		// Compute statistics

		// 1. Average loan amount
		DataStream<Double> avgLoanAmount = loanApplications
			.map(new MapFunction<LoanApplication, Tuple2<Double, Integer>>() {
				@Override
				public Tuple2<Double, Integer> map(LoanApplication app) throws Exception {
					return new Tuple2<>(app.loanAmountRequested != null ? app.loanAmountRequested : 0.0, 1);
				}
			})
			.keyBy(value -> 1) // Use constant key for global aggregation
			.reduce(new ReduceFunction<Tuple2<Double, Integer>>() {
				@Override
				public Tuple2<Double, Integer> reduce(Tuple2<Double, Integer> t1, Tuple2<Double, Integer> t2) throws Exception {
					return new Tuple2<>(t1.f0 + t2.f0, t1.f1 + t2.f1);
				}
			})
			.map(new MapFunction<Tuple2<Double, Integer>, Double>() {
				@Override
				public Double map(Tuple2<Double, Integer> sum) throws Exception {
					return sum.f1 > 0 ? sum.f0 / sum.f1 : 0.0;
				}
			});

		// 2. Count by loan status
		DataStream<Tuple2<String, Integer>> statusCounts = loanApplications
			.map(new MapFunction<LoanApplication, Tuple2<String, Integer>>() {
				@Override
				public Tuple2<String, Integer> map(LoanApplication app) throws Exception {
					return new Tuple2<>(app.loanStatus != null ? app.loanStatus : "Unknown", 1);
				}
			})
			.keyBy(value -> value.f0)
			.reduce(new ReduceFunction<Tuple2<String, Integer>>() {
				@Override
				public Tuple2<String, Integer> reduce(Tuple2<String, Integer> t1, Tuple2<String, Integer> t2) throws Exception {
					return new Tuple2<>(t1.f0, t1.f1 + t2.f1);
				}
			});

		// 3. Count by loan type
		DataStream<Tuple2<String, Integer>> typeCounts = loanApplications
			.map(new MapFunction<LoanApplication, Tuple2<String, Integer>>() {
				@Override
				public Tuple2<String, Integer> map(LoanApplication app) throws Exception {
					return new Tuple2<>(app.loanType != null ? app.loanType : "Unknown", 1);
				}
			})
			.keyBy(value -> value.f0)
			.reduce(new ReduceFunction<Tuple2<String, Integer>>() {
				@Override
				public Tuple2<String, Integer> reduce(Tuple2<String, Integer> t1, Tuple2<String, Integer> t2) throws Exception {
					return new Tuple2<>(t1.f0, t1.f1 + t2.f1);
				}
			});

		// 4. Average monthly income
		DataStream<Double> avgMonthlyIncome = loanApplications
			.map(new MapFunction<LoanApplication, Tuple2<Double, Integer>>() {
				@Override
				public Tuple2<Double, Integer> map(LoanApplication app) throws Exception {
					return new Tuple2<>(app.monthlyIncome != null ? app.monthlyIncome : 0.0, 1);
				}
			})
			.keyBy(value -> 1) // Use constant key for global aggregation
			.reduce(new ReduceFunction<Tuple2<Double, Integer>>() {
				@Override
				public Tuple2<Double, Integer> reduce(Tuple2<Double, Integer> t1, Tuple2<Double, Integer> t2) throws Exception {
					return new Tuple2<>(t1.f0 + t2.f0, t1.f1 + t2.f1);
				}
			})
			.map(new MapFunction<Tuple2<Double, Integer>, Double>() {
				@Override
				public Double map(Tuple2<Double, Integer> sum) throws Exception {
					return sum.f1 > 0 ? sum.f0 / sum.f1 : 0.0;
				}
			});

		// Print statistics to console
		avgLoanAmount.map(new MapFunction<Double, String>() {
			@Override
			public String map(Double avg) throws Exception {
				return String.format("Average Loan Amount: $%.2f", avg);
			}
		}).print("AVG_LOAN_AMOUNT").setParallelism(1);

		avgMonthlyIncome.map(new MapFunction<Double, String>() {
			@Override
			public String map(Double avg) throws Exception {
				return String.format("Average Monthly Income: $%.2f", avg);
			}
		}).print("AVG_MONTHLY_INCOME").setParallelism(1);

		statusCounts.map(new MapFunction<Tuple2<String, Integer>, String>() {
			@Override
			public String map(Tuple2<String, Integer> count) throws Exception {
				return String.format("Loan Status - %s: %d applications", count.f0, count.f1);
			}
		}).print("STATUS_COUNTS").setParallelism(1);

		typeCounts.map(new MapFunction<Tuple2<String, Integer>, String>() {
			@Override
			public String map(Tuple2<String, Integer> count) throws Exception {
				return String.format("Loan Type - %s: %d applications", count.f0, count.f1);
			}
		}).print("TYPE_COUNTS").setParallelism(1);

		// Create CSV output streams for all statistics
		
		// 1. Average loan amount as CSV line
		DataStream<String> avgLoanAmountCsv = avgLoanAmount
			.map(new MapFunction<Double, String>() {
				@Override
				public String map(Double avgAmount) throws Exception {
					return String.format("Average Loan Amount,%.2f", avgAmount);
				}
			});

		// 2. Average monthly income as CSV line  
		DataStream<String> avgMonthlyIncomeCsv = avgMonthlyIncome
			.map(new MapFunction<Double, String>() {
				@Override
				public String map(Double avgIncome) throws Exception {
					return String.format("Average Monthly Income,%.2f", avgIncome);
				}
			});

		// 3. Status counts as CSV lines
		DataStream<String> statusCountsCsv = statusCounts
			.map(new MapFunction<Tuple2<String, Integer>, String>() {
				@Override
				public String map(Tuple2<String, Integer> count) throws Exception {
					return String.format("Loan Status - %s,%d", count.f0, count.f1);
				}
			});

		// 4. Type counts as CSV lines
		DataStream<String> typeCountsCsv = typeCounts
			.map(new MapFunction<Tuple2<String, Integer>, String>() {
				@Override
				public String map(Tuple2<String, Integer> count) throws Exception {
					return String.format("Loan Type - %s,%d", count.f0, count.f1);
				}
			});

		// Union all statistics into one stream
		DataStream<String> allStatsCsv = avgLoanAmountCsv
			.union(avgMonthlyIncomeCsv, statusCountsCsv, typeCountsCsv);

		// Write all statistics to CSV file
		allStatsCsv.addSink(new SinkFunction<String>() {
			private PrintWriter writer;
			private boolean headerWritten = false;

			@Override
			public void invoke(String value, Context context) throws Exception {
				// Initialize writer and write header on first call
				if (writer == null) {
					writer = new PrintWriter(new FileWriter("/tmp/loan_statistics_summary.csv", false));
					if (!headerWritten) {
						writer.println("metric,value");
						headerWritten = true;
					}
				}
				
				writer.println(value);
				writer.flush();
				System.out.println("Written to CSV: " + value);
			}

			@Override
			public void finish() throws Exception {
				if (writer != null) {
					writer.close();
					System.out.println("All statistics written to: /tmp/loan_statistics_summary.csv");
				}
			}
		}).setParallelism(1);

		// Execute the Flink job
		env.execute("Loan Application Batch Processing");
	}
}
