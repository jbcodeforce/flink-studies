# SQL Gateway demo – OSS Flink (local)

## Goal

Flink SQL Gateway: start cluster and gateway, create CSV source table, deploy DML, assess results. Local/OSS Flink only. See root [../README.md](../README.md).

## Status

Ready. Manual steps in root README; no automation in this folder.

## Implementation approach

- **No IaC.** Local Flink cluster + SQL Gateway; [../create_employees.sql](../create_employees.sql), CSV data at root.
- **Application logic:** SQL and data at root.

## How to run

From **demo root**: start Flink cluster and SQL Gateway, run create_employees.sql, load departments.csv and employees.csv, run DML. See [../README.md](../README.md).
