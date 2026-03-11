# Confluent Cloud Flink Table API examples

Java Table API examples for Confluent Cloud for Flink. All classes live under `src/main/java/io/confluent/flink/examples/table/`.

## Examples

| Class | Description |
|-------|-------------|
| **Example_00_HelloWorld** | Minimal setup: two foreground statements, results printed to console. |
| **Example_01_CatalogsAndDatabases** | Catalogs and databases: `SHOW TABLES`, 3-part identifiers, `useCatalog` / `useDatabase`. |
| **Example_02_UnboundedTables** | Bounded vs unbounded statements; catalog listing, `fromValues`, streaming from Kafka. |
| **Example_03_TransformingTables** | Transform data with `Table` API: select, filter, join. |
| **Example_04_CreatingTables** | Create Kafka-backed tables (requires write access to cluster/catalog). |
| **Example_05_TablePipelines** | Pipe data into one or more tables via `StatementSet`; submits unbounded background statement. |
| **Example_06_ValuesAndDataTypes** | Mock data and data types: Java objects, `fromValues`, row/array/map. |
| **Example_07_Changelogs** | Changelogs and stream–table duality (+I, -U, +U). |
| **Example_08_IntegrationAndDeployment** | CI/CD: `setup` / `test` / `deploy` phases for integration testing and rollout. |
| **TableProgramTemplate** | Skeleton with Confluent/Flink imports and structure for new table programs. |

## How to run

Set Confluent Cloud connection (e.g. env or `cloud.properties`), then run the desired class `main` (IDE or `java -jar ... <class>`). Examples that write to Kafka need target catalog/database configured (see in-class constants or env).
