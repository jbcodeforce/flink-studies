# Product Requirements Document: Flink to PostgreSQL Sink Connector Demonstration

## 1. Objective

The primary objective of this demonstration is to showcase the usage of the Flink JDBC Sink connector to write data from a Flink SQL job into a PostgreSQL database. This demonstration will specifically focus on validating the impact of different changelog modes, such as `upsert` and `retract`, on the target database.

The demo will use Confluent Managed Flink for the Flink runtime, and a local or Kubernetes-based PostgreSQL instance as the data sink.

## 2. Scope

### In Scope

*   **Data Source**: Two Kafka topics containing JSON-formatted data representing orders and shipments.
*   **Data Generation**: A script or tool to produce sample data to the source Kafka topics.
*   **Flink SQL Job**: A Flink SQL script that joins the two Kafka topics, performing a stateful transformation.
*   **Data Sink**: A PostgreSQL database to store the results of the Flink SQL job.
*   **Changelog Mode Validation**: The demonstration will clearly show how to configure and validate the `upsert` and `retract` changelog modes.
*   **Technology Stack**:
    *   Confluent Cloud for Kafka and Flink.
    *   PostgreSQL running locally via Docker or on Kubernetes.
    *   Kafka Connect with the JDBC Sink connector.
*   **Documentation**: Clear and concise documentation on how to set up, run, and validate the demonstration.

### Out of Scope

*   A production-ready, highly available deployment.
*   Complex data schemas or business logic beyond what is necessary for the demonstration.
*   A user interface for the demonstration.
*   Performance benchmarking.

## 3. Target Audience

*   Developers and architects interested in learning about Flink's changelog modes and the JDBC Sink connector.
*   Users of Confluent Cloud who want to integrate Flink with external databases.

## 4. User Journey

1.  **Setup**: The user will start by setting up the necessary infrastructure, including Kafka topics on Confluent Cloud and a local PostgreSQL instance.
2.  **Data Generation**: The user will run a script to generate sample data into the source Kafka topics.
3.  **Flink Job Execution**: The user will execute the Flink SQL job on Confluent Managed Flink.
4.  **Validation**: The user will query the PostgreSQL database to observe the effects of the Flink job and the configured changelog mode. The documentation will provide specific queries to run for validation.
5.  **Cleanup**: The user will have instructions on how to tear down the environment.
