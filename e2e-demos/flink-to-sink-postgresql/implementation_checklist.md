# Implementation Checklist

## Phase 1: Project Setup

- [ ] Initialize Git repository
- [ ] Create a `README.md` with a project overview
- [ ] Define project structure
- [ ] Define dependencies (e.g., in a `requirements.txt` or `pom.xml`)

## Phase 2: Infrastructure Setup

- [ ] Configure Confluent Cloud Kafka cluster
- [ ] Create input and output topics on Confluent Cloud
- [ ] Set up a Flink cluster on Confluent Cloud
- [ ] Set up a PostgreSQL instance (local Docker or Kubernetes)
- [ ] Configure the Kafka Connect JDBC Sink connector

## Phase 3: Development

- [ ] Develop a data generator for source topics (orders, shipments)
- [ ] Write the Flink SQL script for the join and transformation logic
- [ ] Configure the Flink job to handle `upsert` and `retract` modes
- [ ] Create the necessary tables in PostgreSQL

## Phase 4: Testing and Validation

- [ ] Test the data generator
- [ ] Run the Flink job and monitor its execution
- [ ] Write and execute SQL queries in PostgreSQL to validate the results of the `upsert` and `retract` operations
- [ ] Document the validation steps and expected outcomes

## Phase 5: Documentation

- [ ] Update the `README.md` with detailed instructions on how to run the demo
- [ ] Add a section to the `README.md` explaining the changelog modes and their impact
- [ ] Create a `PRD.md` (Product Requirements Document)
- [ ] Create this `implementation_checklist.md`
