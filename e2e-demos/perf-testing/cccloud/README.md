# Perf testing — Confluent Cloud for Flink

## Goal

Run the same passthrough pipeline as [../flink-jobs/sql-executor](../flink-jobs/sql-executor/) using Flink SQL statements on Confluent Cloud for Flink (no Java JAR deploy).

## Prerequisites

- Confluent Cloud organization with a Kafka cluster and Flink compute pool
- `confluent` CLI logged in (`confluent login`)
- Topics `perf-input` and `perf-output` on the CC cluster
- Phase 1 [producer](../producer/) built for load generation

## SQL files

| Order | File |
|-------|------|
| 1 | [ddl.perf_source.sql](ddl.perf_source.sql) |
| 2 | [ddl.perf_sink.sql](ddl.perf_sink.sql) |
| 3 | [dml.passthrough.sql](dml.passthrough.sql) |
| 4 | [validate.perf_output.sql](validate.perf_output.sql) (query) |

Deploy via Cloud Console (SQL workspace) or:

```bash
export FLINK_COMPUTE_POOL_ID=lfcp-xxxxxxxx
./deploy-statements.sh
```

## Generate load

Use CC Kafka bootstrap and SASL settings from:

```bash
confluent kafka cluster describe <cluster-id> -o json
```

Then from demo root:

```bash
export BOOTSTRAP_SERVERS=<cc-bootstrap>
# export KAFKA credentials per Confluent docs
./scripts/run-producer.sh 1000 60
```

Validate with `validate.perf_output.sql` in the Flink workspace or `./scripts/validate-run.sh` if bootstrap is reachable locally.

## Related

- [flink-statement-troubleshooting](https://github.com/jbcodeforce/flink-studies) research tooling may use this passthrough as a live fixture
- Parent [README](../README.md) Phase 3
