# CDC Table API to silver – OSS Flink

## Goal

Run the same Debezium-mock pipeline (raw → silver → dim_account, fct_transactions) with local Kafka and OSS Flink (SQL client or Table API Java at [../java/](../java/)).

## Status

Ready. Local Kafka + Flink or OSS Flink on K8s.

## Implementation approach

- **No IaC in this folder.** Shared SQL and Java at root; [../run_tests.sh](../run_tests.sh) for validation.
- **Application logic:** [../sources/](../sources/), [../dimensions/](../dimensions/), [../facts/](../facts/), [../raw_topic_for_tests/](../raw_topic_for_tests/).

## How to run

From **demo root**: apply DDL/DML in Flink SQL client or run the Table API job; run run_tests.sh. See root [README.md](../README.md).
