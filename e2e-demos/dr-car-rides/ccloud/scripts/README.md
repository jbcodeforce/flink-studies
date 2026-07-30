# Operational scripts

| Script | Purpose |
|--------|---------|
| `export-env.sh` | `source` Kafka **and Schema Registry** credentials for `primary` or `dr` from `iac-outputs.json` |
| `failover-soft.sh` | Stop primary Flink (best-effort), notes for SR IMPORT→READWRITE, apply Flink+Tableflow on DR |
| `failover-promote.sh` | Promote/failover mirrors then run soft deploy |
| `failback.sh` | Documented failback including Schema Linking reverse |

Generate outputs after Phase 1:

```bash
cd ../IaC && terraform output -json > ../scripts/iac-outputs.json
```

`iac-outputs.json` contains secrets — do not commit it (see `.gitignore`).
