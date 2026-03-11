# CDC Table API to silver – Confluent Cloud

## Goal

Run the Debezium-mock pipeline (raw accounts/transactions → silver → dim_account, fct_transactions) on Confluent Cloud for Flink. Same pipeline as [../README.md](../README.md); deploy via Flink workspace or Confluent CLI.

## Status

Ready. Confluent Cloud with Kafka and Flink compute pool (or local Kafka + Flink with schema registry).

## Implementation approach

- **No IaC in this folder.** Use Confluent Cloud UI or Terraform from [deployment/cc-terraform](../../../deployment/cc-terraform/)
- **Application logic:** Shared at root: [../sources/](../sources/), [../dimensions/](../dimensions/), [../facts/](../facts/), [../raw_topic_for_tests/](../raw_topic_for_tests/). Run [../run_tests.sh](../run_tests.sh) for validation.

## How to run

From **demo root**: apply DDL/DML in order (raw → silver → dim/fact) in Flink workspace or via CLI. Insert test data from raw_topic_for_tests, run run_tests.sh. See root [README.md](../README.md).
