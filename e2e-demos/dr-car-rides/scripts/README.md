# Operational scripts

| Script | Purpose |
|--------|---------|
| `export-env.sh` | `source` Kafka, Schema Registry, and Flink (API key/secret, pool, REST, database) for `primary` or `dr` from `iac-outputs.json` |
| `cleanup-dr.sh` | Resets DR before a rerun: stops `produce_rides.py` on the laptop AND the bastion, deletes the DR dbt statements, the `rides_clean` / `driver_stats` topics and their subjects (`--include-raw` also drops `rides_raw`, `--reset-seq-log` clears the seq logs). The DR part runs on the bastion |
| `apply-cluster-link.sh` | Layer 2 from the laptop: runs `terraform apply` (or `--plan` / `--destroy`) for `IaC/02-cluster-link` ON THE BASTION, where the private DR Kafka REST endpoint resolves |
| `require-private-dns.sh` | Exits with a clear message when a DR private endpoint does not resolve (step run outside the DR VPC) |
| `failover-soft.sh` | Stop primary Flink (best-effort), notes for SR IMPORT→READWRITE, apply Flink+Tableflow on DR |
| `failover-promote.sh` | Runs on the bastion: promote (`--mode promote`, waits lag 0) or failover (`--mode failover`) the mirrors |
| `simulate-primary-outage.sh` | Inject a primary outage by deleting the producer and Flink CloudClusterAdmin role bindings; `--restore` undoes it |
| `failover-hard.sh` | Unplanned failover with the primary down: best-effort primary stop, DR SR READWRITE, mirror `failover`, dbt on DR, loss report |
| `failback.sh` | Documented failback including Schema Linking reverse |

Generate outputs after Phase 1:

```bash
./generate-outputs.sh   # merges the outputs of every applied IaC layer (planned, see dr-demo-execution-plan.md)
```

`iac-outputs.json` contains secrets — do not commit it (see `.gitignore`).
