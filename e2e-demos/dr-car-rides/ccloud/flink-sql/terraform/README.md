# Phase 2 — Flink SQL + Tableflow

Deploys DDL/DML against **primary** by default. For DR failover, use a separate state dir:

```bash
# Primary (steady state)
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# DR (on failover) — separate workspace/state to avoid destroying primary statements
mkdir -p ../dr-state && cd ../dr-state
terraform -chdir=../terraform init
terraform -chdir=../terraform apply \
  -var="deploy_site=dr" \
  -var="statement_name_prefix=dr-rides-dr" \
  -state=./terraform.tfstate
```

Or use `../../scripts/failover-soft.sh`, which invokes the same apply path.
