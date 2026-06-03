# DataStream job

Flink **2.2.0** Kafka source → passthrough → Kafka sink (string JSON values).

## Build

```bash
mvn -f pom.xml clean package
```

## Run

```bash
export BOOTSTRAP_SERVERS=localhost:9092
../../scripts/run-flink-job.sh datastream
```

Environment: `INPUT_TOPIC` (default `perf-input`), `OUTPUT_TOPIC` (default `perf-output`), consumer group `perf-datastream`.

## Compare with sql-executor

Run the same producer profile against both jobs to compare Table API/SQL vs DataStream under identical load ([../../README.md](../../README.md)).
