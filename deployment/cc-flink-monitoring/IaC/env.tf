resource "local_file" "prometheus_config" {
  filename = "${path.module}/../prometheus/prometheus.yml"
  content = templatefile("${path.module}/../prometheus/prometheus.tmpl.yml", {
    metrics_api_key_id    = confluent_api_key.metrics.id
    metrics_api_key_secret = confluent_api_key.metrics.secret
    kafka_cluster_id      = local.kafka_cluster_id
    schema_registry_id    = local.schema_registry_id
    compute_pool_ids_yaml = join("\n        - ", local.compute_pool_ids)
  })

  depends_on = [confluent_api_key.metrics]
}
