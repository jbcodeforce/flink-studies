# Loan Application Batch Processing

The project has two complementary jobs:

* DataStreamJob: General statistics using DataStream API
* TableApiJob: Advanced fraud analysis using Table API + SQL

## Goals

* Load loan_application.csv (from the e2e-demos/cdc-demo/datasets)
* Compute average loan amount and other statistics.
* Write outcome on the console and then to an output csv file

## DataStream Implementation

This Flink batch processing job:

1. Uses Flink's file connector to read the loan applications CSV file
2. Parses CSV records into `LoanApplication` POJO objects
3. **Statistics Computation**:
   - Average loan amount requested
   - Average monthly income
   - Count of applications by loan status (Approved/Declined)
   - Count of applications by loan type (Personal/Business/Home/Car/Education)
4. **Output**: 
   - Prints all statistics to console with labeled output
   - Writes **all computed statistics** to `/tmp/loan_statistics_summary.csv`
   - Shows sample records for verification

### Key Components

- **`LoanApplication.java`**: POJO class representing the data in the csv file and with a fromCsvLine() method to do CSV parsing
- **`DataStreamJob.java`**: Main Flink job with processing pipeline using DataStream API
   * Reads the 50,000+ loan applications from the CSV file
   * Filters out header and invalid records
   * Computes the following statistics:
      * Average loan amount requested
      * Average monthly income
      * Count by loan status (Approved/Declined)
      * Count by loan type (Personal/Business/Home/Car/Education)
      * Prints all results to console with clear labels
      * Writes summary statistics to /tmp/loan_statistics_summary.csv
- **`TableApiJob.java`**: Fraud analysis job using Flink Table API with SQL queries
   * Analyzes fraudulent loan applications using SQL-based queries
   * Computes comprehensive fraud statistics and patterns
   * Outputs detailed fraud analysis to console and CSV file
- **`pom.xml`**: Maven configuration with Flink file connector and Table API dependencies

## How to Run

### DataStream API Job (General Statistics)
1. Ensure you have Maven and Java 8+ installed
2. Build the project: `mvn clean package`
3. Run with Flink: 
   ```bash
   $FLINK_HOME/bin/flink run target/loan-application-0.1.jar
   ```
   Or when using OSS Flink run directly in IDE: `DataStreamJob.main()`

### Table API Job (Fraud Analysis)
Run the fraud analysis job:
- In IDE: Run `TableApiJob.main()`
- Or with Flink CLI: Update pom.xml mainClass to `j9r.flink.loanapp.TableApiJob` and build/run

## Data Source

The job reads from: `flink-studies/e2e-demos/cdc-demo/datasets/loan_applications.csv`

Contains 50,000+ loan applications with fields like loan amount, customer details, employment status, and approval status.

## Output Files

### DataStream Job Output
- Console: Real-time statistics and sample records
- `/tmp/loan_statistics_summary.csv`: Comprehensive statistics including:
  - Average loan amount and monthly income
  - Count of applications by loan status (Approved/Declined)
  - Count of applications by loan type (Personal/Business/Home/Car/Education)

### Table API Job Output (Fraud Analysis)
- Console: Detailed fraud analysis results with SQL-based insights
- `/tmp/fraud_analysis_results.csv`: Comprehensive fraud analysis including:
  - Total number of fraudulent loan applications
  - Fraud breakdown by loan type (Personal/Business/Home/Car/Education)
  - Fraud classification by fraud type (when specified)
  - Fraud rate percentage by loan status (Approved vs Declined)
  - Comparative analysis: Average loan amounts and income for fraudulent vs legitimate applications