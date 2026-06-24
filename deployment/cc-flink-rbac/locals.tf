locals {
  environment_display_name        = var.environment_display_name != "" ? var.environment_display_name : "j9r-env"
  kafka_cluster_display_name_res  = var.kafka_cluster_display_name != "" ? var.kafka_cluster_display_name : "${var.prefix}-kafka"
  flink_compute_pool_display_name = var.flink_compute_pool_display_name != "" ? var.flink_compute_pool_display_name : "${var.prefix}-pool"

  env_id = (
    var.create_environment ? confluent_environment.env[0].id
    : var.use_remote_state ? data.terraform_remote_state.cc[0].outputs.env_id
    : var.environment_id
  )
}

# Always resolve the real environment display name (Flink catalog name).
data "confluent_environment" "current" {
  id = local.env_id
}

locals {
  org_id = coalesce(
    var.organization_id != "" ? var.organization_id : null,
    data.confluent_organization.org.id,
  )

  env_display_name = coalesce(
    var.environment_display_name != "" ? var.environment_display_name : null,
    data.confluent_environment.current.display_name,
  )

  kafka_cluster_display_name = (
    var.create_kafka_cluster ? confluent_kafka_cluster.kafka[0].display_name
    : var.sql_current_database != "" ? var.sql_current_database
    : try(data.terraform_remote_state.cc[0].outputs.kafka_cluster_display_name, "")
  )

  flink_compute_pool_id = coalesce(
    var.create_flink_compute_pool ? confluent_flink_compute_pool.pool[0].id : null,
    var.flink_compute_pool_id != "" ? var.flink_compute_pool_id : null,
    try(data.terraform_remote_state.cc[0].outputs.flink_dev-j9r-pool_id, ""),
  )

  sql_current_catalog = coalesce(
    var.sql_current_catalog != "" ? var.sql_current_catalog : null,
    local.env_display_name,
  )

  sql_current_database = coalesce(
    var.sql_current_database != "" ? var.sql_current_database : null,
    local.kafka_cluster_display_name != "" ? local.kafka_cluster_display_name : null,
  )

  flink_rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
}
