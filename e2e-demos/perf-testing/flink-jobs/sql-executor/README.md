# SqlExecutor (Table API + SQL)

Flink **2.2.0** job that runs [src/main/resources/pipeline.sql](src/main/resources/pipeline.sql): Kafka JSON source → Kafka JSON sink (passthrough).

## Build

```bash
mvn -f pom.xml clean package
```

## Run (local)

```bash
export BOOTSTRAP_SERVERS=localhost:9092
export INPUT_TOPIC=perf-input
export OUTPUT_TOPIC=perf-output
flink run target/perf-sql-executor-0.1.0.jar
```

Or: `../../scripts/run-flink-job.sh sql-executor`

## Custom SQL file

```bash
flink run target/perf-sql-executor-0.1.0.jar /path/to/script.sql
```

Placeholders `${BOOTSTRAP_SERVERS}`, `${INPUT_TOPIC}`, `${OUTPUT_TOPIC}` are replaced from the environment.

## Kubernetes

- OSS: [../../oss-flink/README.md](../../oss-flink/README.md)
- CP/CMF: [../../cp-flink/README.md](../../cp-flink/README.md)
