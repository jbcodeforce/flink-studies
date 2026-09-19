# -----------------------------------------------------------------------------
# Outputs — Primary Site
# -----------------------------------------------------------------------------
output "organization_id" {
  value = data.confluent_organization.org_id.id
}

output "primary_environment_display_name" {
  value = data.confluent_environment.primary_env.display_name
}

output "primary_schema_registry_id" {
  value = data.confluent_schema_registry_cluster.primary_sr.id
}

output "primary_schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.primary_sr.rest_endpoint
}

output "primary_kafka_cluster_id" {
  value = data.confluent_kafka_cluster.primary_lkc.id
}

output "primary_kafka_cluster_display_name" {
  value = data.confluent_kafka_cluster.primary_lkc.display_name
}

output "primary_kafka_cluster_region" {
  value = data.confluent_kafka_cluster.primary_lkc.region
}

output "primary_kafka_cluster_bootstrap" {
  value = data.confluent_kafka_cluster.primary_lkc.bootstrap_endpoint
}


# ---------------------
# DR information
# ---------------------

output "dr_environment_display_name" {
  value = resource.confluent_environment.dr.display_name
}

output "dr_environment_id" {
  value = resource.confluent_environment.dr.id
}


output "dr_kafka_cluster_id" {
  value = resource.confluent_kafka_cluster.dr_lkc.id
}

output "dr_kafka_cluster_display_name" {
  value = resource.confluent_kafka_cluster.dr_lkc.display_name
}

output "dr_kafka_cluster_region" {
  value = resource.confluent_kafka_cluster.dr_lkc.region
}

output "dr_kafka_cluster_bootstrap" {
  value = resource.confluent_kafka_cluster.dr_lkc.bootstrap_endpoint
}