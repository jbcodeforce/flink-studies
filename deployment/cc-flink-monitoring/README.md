# Monitoring Confluent Cloud Flink Statement Metrics

Docker Compose runs Prometheus and Grafana for Confluent Cloud Flink compute pool and statement metrics. See [Getting started with Grafana and Prometheus](https://grafana.com/docs/grafana/latest/fundamentals/getting-started/first-dashboards/get-started-grafana-prometheus/).

## Prerequisites

1. [deployment/cc-terraform](../cc-terraform/) applied with a local `terraform.tfstate` (base j9r-env infrastructure).
2. Confluent Cloud API keys with OrganizationAdmin role for Terraform provider auth.

## Setup

Terraform in this folder reads resource IDs from `cc-terraform` remote state, creates a MetricsViewer service account and cloud API key, then generates:

- `.env` — environment variables for scripts and tooling
- `prometheus/prometheus.yml` — Prometheus scrape config (contains secrets; gitignored)

```bash
# 1. Ensure base infrastructure is applied
cd ../cc-terraform
export TF_VAR_confluent_cloud_api_key="<org-admin-key>"
export TF_VAR_confluent_cloud_api_secret="<org-admin-secret>"
terraform apply

# 2. Apply monitoring stack
cd ../cc-flink-monitoring
export TF_VAR_confluent_cloud_api_key="<org-admin-key>"
export TF_VAR_confluent_cloud_api_secret="<org-admin-secret>"
terraform init
terraform plan
terraform apply
```

After apply, inspect outputs:

```bash
terraform output -raw prometheus_metrics_api_key_id
terraform output -raw prometheus_metrics_api_key_secret
cat .env
```

Re-run `terraform apply` whenever compute pools or cluster IDs change in `cc-terraform`.

### Manual alternative

Copy scrape configuration from the [Confluent Cloud Prometheus integration UI](https://confluent.cloud/settings/metrics/integrations?integration=prometheus). Select "All resources" instead of the default "All Kafka clusters". See [prometheus/prometheus.example.yml](./prometheus/prometheus.example.yml) for the expected shape.

## Start monitoring

```bash
docker compose up -d
```

Grafana dashboard data persists via a volume mount under `grafana/`.

## Access

- **Grafana**: `http://localhost:3010` — username `admin`, password `admin`
- **Prometheus**: `http://localhost:9090`

## Verify

1. Scrape target healthy: Status → Targets — the Confluent Cloud job should be UP.

Or in Graph:
```yaml
up{job="Confluent Cloud"}
```

2. Any Flink compute pool metrics present: 
```yaml
{__name__=~"confluent_flink_compute_pool.*"}
```

If this returns nothing, the scrape is failing or pool IDs in prometheus.

3. Which pools Prometheus sees
```yaml
count by (compute_pool_id) (confluent_flink_compute_pool_utilization_current_cfus)
```

Same query as the Grafana “Compute Pools” panel — one series per pool.

List pool IDs only:
```yaml
group by (compute_pool_id) (confluent_flink_compute_pool_utilization_current_cfus)
```

4. Utilization (main health check)

Current CFUs per pool:

```yaml
confluent_flink_compute_pool_utilization_current_cfus
```

CFU limit per pool:

```yaml
confluent_flink_compute_pool_utilization_cfu_limit
```

Utilization ratio (0–1, or ×100 for %):
```yaml
confluent_flink_compute_pool_utilization_current_cfus
  / confluent_flink_compute_pool_utilization_cfu_limit
```

Filter one pool (replace with your ID from .env / FLINK_COMPUTE_POOL_IDS):
```yaml
confluent_flink_compute_pool_utilization_current_cfus{compute_pool_id="lfcp-xxxxx"}
```

### Instant query returns empty but target is UP

Confluent's `/export` endpoint embeds metric timestamps that lag scrape time by several minutes. With `honor_timestamps: true`, Prometheus stores samples in the past and instant queries at "now" return no data (while `offset 2m` or range queries still work).

This stack sets `honor_timestamps: false` so samples use scrape time. After changing config:

```bash
curl -X POST http://localhost:9090/-/reload
# or: docker compose restart prometheus
```

Wait one scrape interval (1m), then re-run the query. Idle pools report `0` CFUs — that is valid data, not missing metrics.

### Grafana shows no data

The dashboard must use the same Prometheus datasource UID as [grafana/datasources/datasource.yml](./grafana/datasources/datasource.yml) (`flink-workshop-prometheus`). A mismatch (e.g. `cc-flink-prometheus` in panel JSON) causes empty panels even when Prometheus has data.

After editing `grafana/dashboards/dashboard.json`, wait ~10s for provisioning to reload, or restart Grafana:

```bash
docker compose restart grafana
```

Test the datasource in Grafana: **Connections → Data sources → prometheus → Save & test**.

### Statement lag panels

The **Statement Lag** row tracks timeliness and backlog for selected statements:

| Panel | Metric | Meaning |
|-------|--------|---------|
| Max Pending Records | `confluent_flink_pending_records` | Kafka backlog not yet consumed by the statement |
| Max Input Lateness | `confluent_flink_max_input_lateness_milliseconds` | Event-time lateness at the source (empty when no late events) |
| Output/Input Watermark Lag | `current_*_watermark_milliseconds` vs `time()` | Wall-clock minus current watermark (event-time completeness) |

Lag metrics appear only for **running** statements with active traffic. Completed or idle statements may show no series.

#### Watermark lag: findings and interpretation

The dashboard computes wall-clock lag as `time() * 1000 - current_*_watermark_milliseconds`. Two cases matter for this demo:

**1. Absurd values (e.g. hundreds of millions of years)**

Flink exports an uninitialized watermark as `Long.MIN_VALUE` (~`-9.22e18` ms) when no valid watermark has been assigned yet. Subtracting that from wall-clock time produces ~`9e18` ms, which Grafana auto-formats as hundreds of millions of years.

This commonly happens when:

- The Kafka source is **idle** after a bounded history load (`pending_records = 0`, no new records)
- One or more partitions never received data and still hold the minimum watermark

The dashboard filters out invalid watermarks (`watermark_milliseconds > 946684800000`, i.e. after year 2000). When the metric is unset, panels show **No data** instead of a bogus lag.

**2. Large but realistic values (days to ~1 year)**

The demo loads transactions with `ts` spread over the last 365 days. During replay, event-time watermarks trail wall-clock time by design: a watermark at May 2025 while "now" is May 2026 yields ~365 days of lag. That is expected for historical backfill, not a fault.

For windowed statements, Confluent also recommends tracking **in-flight** data as output minus input watermark:

```promql
confluent_flink_current_output_watermark_milliseconds{flink_statement_name="monitoring-dml-user-monthly-totals"}
  - confluent_flink_current_input_watermark_milliseconds{flink_statement_name="monitoring-dml-user-monthly-totals"}
```

For tumbling windows this rises until a window fires, then drops.

**Pipeline mitigations** (see [cc-flink/README.md](./cc-flink/README.md)):

- `scan.watermark.idle-timeout = '1 min'` on the `transactions` table so idle partitions stop blocking watermark advancement
- Recreate the table after DDL changes: `make undeploy && make deploy` from `cc-flink/`

Raw watermark values (sanity check):

```promql
confluent_flink_current_input_watermark_milliseconds{flink_statement_name="monitoring-dml-user-monthly-totals"}
```

Values near `-9.22e18` mean unset; values around `1.7e12` are normal epoch-ms timestamps.

## Demo workload (statement metrics)

Deploy the sample pipeline in [cc-flink/](./cc-flink/) to load one year of transaction history and run the monthly rollup:

```bash
cd cc-flink
make sync    # once
make deploy
make produce-transactions
```

Uses `FLINK_COMPUTE_POOL_ID` from `~/.confluent/.env`. After deploy, filter Grafana **Statement(s)** to:

- `monitoring-dml-user-monthly-totals` — 30-day aggregation over historical `ts`
- `monitoring-dml-load-users` — one-shot user seed

Teardown: `make undeploy` from `cc-flink/`.

## Security


- Do not commit `.env`, `prometheus/prometheus.yml`, or Terraform state files.
- The monitoring stack creates `{prefix}-metrics-viewer` with MetricsViewer role at organization scope.

## Build dashboards

See [Create dashboard](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/create-dashboard/).
