# Batching messages

## Problem Statement

There is a set of messages coming as raw &lt;key, value&gt; that needs to be filtered and JSON unnested from the `value`. The goal is to process 10k msg/s.

The data pipeline has a high volume of lead data from Postgres to Elasticsearch. There are 1 billion target documents in Elasticsearch, grouped by tenant. The pipeline is implemented in Flink SQL.

## Design

### Data flow

1. **Source**: Raw lead stream (e.g. Kafka topic) with `key` and `val` (JSON).
2. **Filter**: Exclude delete markers: `__op = 'd'` in the JSON value.
3. **Window**: TUMBLE on `$rowtime` (e.g. 1 second) to batch events.
4. **Bucket**: `MOD(ABS(HASH_CODE(key)), N)` to spread load across N parallel keys for the sink.
6. **Aggregate**: LISTAGG of val separated by \n, like NDJSON,  per (window_start, window_end, bucket) into a single payload.
7. **Sink**: One row per (bucket) with `key` = bucket id and `val` = concatenated bytes (e.g. NDJSON for Elasticsearch bulk API).

```mermaid
flowchart LR
  Source[Lead source]
  Filter[Filter deletes]
  Window[TUMBLE 1s]
  Bucket[Hash bucket]
  Agg[LISTAGG]
  Sink[Bulk sink]
  Source --> Filter --> Window --> Bucket --> Agg --> Sink
```

### Design choices

- **Filter**: Deletes are excluded to do not do processing on tombstone or soft-delete records.
- **Window size**: 1 s gives ~1 s latency; with 5 buckets that is up to ~2k messages per (window, bucket) at 10k msg/s. Increase the interval (e.g. 2–5 s) if the bulk API prefers fewer, larger requests.
- **Bucket count**: Match sink parallelism (e.g. 5). Tune with window size.

### Artifacts

| File | Purpose |
|------|---------|
| [faker.lead.sql](cc-flink/faker.lead.sql) | Create fake data for leads |
| [ddl.lead_source.sql](cc-flink/ddl.lead_source.sql) | DDL for the lead source table. |
| [dml.flatten_leads.sql](cc-flink/dml.flatten_leads.sql) | dml to create the raw data to simulate outcome of CDC postgres as <key,value> | 
| [ddl.bulk_leads.sql](cc-flink/ddl.bulk_leads.sql) | DDL to create sink table |
| [create_build_leads.sql](cc-flink/dml.create_build_leads.sql) |  rekey to the bucket id, with NDJSON |

### Terraform (Confluent Cloud)

The [terraform/](terraform/) directory creates the five Flink statements in dependency order on Confluent Cloud: DDL for `leads_raw` and `bulk_leads`, faker table `leads_faker`, then DML to stream from faker into `leads_raw` and from `leads_raw` into `bulk_leads`.

From `terraform/`, set the required variables (e.g. via `terraform.tfvars` or `-var`) and run:

```bash
cd terraform
terraform init
terraform apply
```

Required variables: `environment_id`, `flink_compute_pool_id`, `kafka_cluster_id`, `principal_id`, `flink_api_key`, `flink_api_secret`. Optional: `flink_rest_endpoint`, `statement_name_prefix` (default `grouping-messages`). Provider auth can use `confluent_cloud_api_key` / `confluent_cloud_api_secret` or `CONFLUENT_CLOUD_API_KEY` / `CONFLUENT_CLOUD_API_SECRET` env vars.

### Inspecting results

- Query the sink table: `SELECT * FROM bulk_leads;`
