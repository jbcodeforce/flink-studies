# Loan Application Batch Processing

The project has two complementary jobs:

* DataStreamJob: General statistics using DataStream API
* TableApiJob: Advanced fraud analysis using Table API + SQL

## Goals

* Load loan_application.csv (from the e2e-demos/cdc-demo/datasets)
* Compute average loan amount and other statistics.
* Write outcome on the console and then to an output csv file

## Implementation

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

For the TableApiJob, it computes fraud analysis.

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

### TableAPI and SQL

The first fraud aggregation is simple:

```sql
 SELECT COUNT(*) as total_fraudulent_loans FROM loan_applications WHERE fraudFlag = 1
```


internaly, Flink will use a GroupAggregate which produces a stream of records that includes updates. Many Flink table sinks, particularly those designed for file systems (like CSV, Parquet, or ORC sinks), are inherently append-only. They are designed to simply add new records to the end of a file or partition and do not have the mechanism to modify or delete existing records. Sinks such as a JDBC sink or a connector to a message queue that can handle key-based updates.

To use Duckdb as a sink and JDBC Sink connector, the following needs to be done:

1. Add pom dependencies: `org.duckdb.duckdb_jdbc` and `org.apache.flink.flink-connector-jdbc`
1. In the FraudCountTableApi.java:
   ```
   // DuckDB connection settings
   String duckdbPath = "/tmp/fraud_analysis.db";
   String jdbcUrl = "jdbc:duckdb:" + duckdbPath;
   ```
1. Once the code is packaged and executed the /tmp/ is created, use the duckdb cli to connect and query the database 
1. Install duckdb cli: `brew install duckdb` . See the [CLI Command documentation](https://duckdb.org/docs/stable/clients/cli/overview).
   ```sh
   # Use the verification script (recommended)
   ./verify_duckdb.sh
   
   # Or manually connect
   duckdb /tmp/fraud_analysis.db
   ```
1. Run some queries like:
   ```sql
   SELECT * FROM fraud_analysis ORDER BY analysis_timestamp DESC;
   -- get the latest fraud count
   SELECT total_fraudulent_loans, analysis_timestamp 
   FROM fraud_analysis 
   WHERE analysis_type = 'fraud_count_analysis'
   ORDER BY analysis_timestamp DESC LIMIT 1;
   ```

## How to Run

### DataStream API Job (General Statistics)

1. Ensure you have Maven and Java 11+ installed
2. Build the project: `mvn clean package`
3. Run with Flink: 
   ```bash
   flink run target/loan-application-0.1.jar
   ```
   Or when using OSS Flink run directly in IDE: `DataStreamJob.main()`

### Table API Job (Fraud Analysis)

* Change the main class name in the tar plugin in pom.xml to `j9r.flink.loanapp.TableApiJob` and build with `mvn package`
* Run the fraud analysis job:
   ```bash
   flink run target/loan-application-0.1.jar
   ```

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
- **DuckDB Database**: `/tmp/fraud_analysis.db` with structured fraud analysis data using **UPSERT mode**
  - Table: `fraud_analysis` with columns and **composite primary key**:
    - `analysis_date`: Date of analysis (PRIMARY KEY part)
    - `analysis_type`: Type of analysis performed (PRIMARY KEY part, e.g., 'fraud_count_analysis')
    - `analysis_timestamp`: When the analysis was last updated  
    - `total_fraudulent_loans`: Number of fraudulent applications detected
  - **Upsert Behavior**: Multiple runs on the same date will **update** the existing record rather than create duplicates
- **Query Examples**: See `query_duckdb.sql` for sample queries to analyze results and track daily trends