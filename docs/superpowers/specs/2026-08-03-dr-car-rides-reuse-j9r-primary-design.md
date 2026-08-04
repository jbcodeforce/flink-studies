# DR Car Rides — Reuse j9r-env as Primary

Date: 2026-08-03  
Status: approved for implementation planning  
Scope: `e2e-demos/dr-car-rides/ccloud/IaC`

## Goal

Stop creating a new primary Confluent environment and Kafka cluster for the DR car-rides demo. Reuse the existing `j9r-env` / `j9r-kafka` imported under `IaC/import-j9r-env`. The DR IaC stack creates only the secondary (DR) environment and cluster, plus demo wiring (topics, Cluster Linking, Schema Linking, Flink pools, Tableflow, API keys, role bindings).

## Decisions

| Decision | Choice |
|----------|--------|
| Primary reuse | Both `j9r-env` and `j9r-kafka` |
| Regions | Primary `us-west-2` (existing cluster), DR `us-east-1` |
| Service accounts | Reuse j9r SAs; create new API keys and role bindings |
| Discovery | `terraform_remote_state` from `import-j9r-env` |
| Primary Flink pool | Always create a new demo pool in `j9r-env`; also create DR pool |

## Architecture

```
import-j9r-env/     read-only catalog of existing org resources
  outputs.tf        focused j9r env / kafka / SA outputs
        |
        v  terraform_remote_state (local backend path)
IaC/                DR demo stack
  primary           data sources + locals (no create/destroy)
  secondary         create DR env + Kafka + Flink pool
  wiring            topics, cluster link, schema linking, Tableflow, keys, RBAC
```

### Ownership

| Resource | Owner |
|----------|--------|
| `j9r-env` (`env-yk3jm6`), `j9r-kafka` (`lkc-7v233w`) | `import-j9r-env` only |
| j9r service accounts | `import-j9r-env` only |
| DR environment + DR Kafka cluster | DR IaC creates |
| Flink compute pools (primary + DR) | DR IaC creates |
| Topics, Cluster Link, Schema Linking, Tableflow, API keys, role bindings | DR IaC creates |

`terraform destroy` on the DR IaC must not destroy j9r primary resources. That follows from referencing them only via remote state and data sources.

## Remote-state contract

### New outputs on `import-j9r-env`

| Output | Source resource |
|--------|-----------------|
| `environment_id` | `confluent_environment.j9r_env_28.id` |
| `environment_display_name` | `j9r_env_28.display_name` |
| `environment_resource_name` | `j9r_env_28.resource_name` |
| `kafka_cluster_id` | `confluent_kafka_cluster.j9r_kafka_10.id` |
| `kafka_display_name` | `j9r_kafka_10.display_name` |
| `kafka_bootstrap_endpoint` | `j9r_kafka_10.bootstrap_endpoint` |
| `kafka_rest_endpoint` | `j9r_kafka_10.rest_endpoint` |
| `kafka_rbac_crn` | `j9r_kafka_10.rbac_crn` |
| `kafka_region` | `j9r_kafka_10.region` |
| `env_manager_sa_id` | `j9r-env-manager` (`j9r_env_manager_110`) |
| `kafka_mgr_sa_id` | `j9r-kafka-mgr` (`j9r_kafka_mgr_3`) |
| `flink_app_sa_id` | `j9r-flink-app` (`j9r_flink_app_94`) |
| `fd_sa_id` | `j9r-fd-sa` (`j9r_fd_sa_19`) |

Known IDs (for verification): env `env-yk3jm6`, cluster `lkc-7v233w`, region `us-west-2`.

### DR IaC remote state

```hcl
data "terraform_remote_state" "j9r" {
  backend = "local"
  config = {
    path = "${path.module}/import-j9r-env/terraform.tfstate"
  }
}
```

Apply order: refresh `import-j9r-env` outputs first (`terraform apply` there after adding `outputs.tf`), then run DR IaC.

## Service account mapping

| Demo role (current resource name) | Reused SA |
|-----------------------------------|-----------|
| `app_manager` | `j9r-env-manager` |
| `flink` | `j9r-flink-app` |
| `producer` | `j9r-kafka-mgr` |

Implementation detail:

- Remove managed `confluent_service_account` resources for those three roles.
- Load SA attributes with `data "confluent_service_account"` by ID from remote state (needed for `api_version` / `kind` on API keys).
- Keep creating demo-scoped API keys and role bindings (EnvAdmin on primary + DR, FlinkDeveloper, CloudClusterAdmin, SR ResourceOwner, etc.).
- Bind EnvAdmin on the existing primary env using `environment_resource_name` from remote state / data source.

## Code changes (DR IaC)

### Stop creating

- `confluent_environment.primary`
- `confluent_kafka_cluster.primary`
- `confluent_service_account.app_manager`
- `confluent_service_account.flink`
- `confluent_service_account.producer`

### Add / replace

- `data.terraform_remote_state.j9r`
- `data.confluent_environment.primary` (id from remote state)
- `data.confluent_kafka_cluster.primary` (id + environment from remote state)
- `data.confluent_service_account` for the three reused SAs
- Locals that alias previous `confluent_environment.primary` / `confluent_kafka_cluster.primary` / SA references so downstream files (`cluster-link.tf`, `schema-linking.tf`, `service-accounts.tf`, `outputs.tf`, `aws.tf` Tableflow PI) keep a single naming convention

### Keep creating

- `confluent_environment.dr`
- `confluent_kafka_cluster.dr`
- `confluent_flink_compute_pool.primary` (in j9r-env)
- `confluent_flink_compute_pool.dr`
- Primary topics, bidirectional cluster link, DR mirrors
- Schema Linking (DR SR `IMPORT` + exporter)
- Tableflow provider integrations (both envs) when enabled
- All demo API keys and role bindings

### Defaults and docs

- `variables.tf` / `terraform.tfvars.example`: `primary_region = "us-west-2"`, `dr_region = "us-east-1"`
- Update `IaC/README.md` and `ccloud/README.md` for reuse model and apply order
- Optional: note in `DESIGN.md` that primary is shared `j9r-env`

## Out of scope

- Slimming the org-wide import in `import-j9r-env/main.tf` (leave catalog as-is; only add outputs)
- Changing Flink SQL Terraform or failover scripts beyond region/output assumptions
- Creating a dedicated producer SA (reuse `j9r-kafka-mgr` instead)
- Moving remote state to a remote backend

## Success criteria

1. `terraform plan` in DR IaC does not propose create/destroy of `j9r-env` or `j9r-kafka`.
2. Plan proposes create of DR environment, DR Kafka cluster, Flink pools, linking, and keys.
3. Outputs still expose primary/DR IDs, endpoints, and keys for `scripts/export-env.sh`.
4. Destroy of DR IaC leaves `j9r-env` / `j9r-kafka` / j9r SAs intact.
5. Docs document apply order: import stack outputs, then DR IaC.
