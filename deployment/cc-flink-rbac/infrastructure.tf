# GCP (or AWS/Azure) environment, Kafka cluster, and Flink compute pool.
# Set create_environment = false and provide environment_id to attach to an existing env.

resource "confluent_environment" "env" {
  count        = var.create_environment ? 1 : 0
  display_name = local.environment_display_name

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_kafka_cluster" "kafka" {
  count        = var.create_kafka_cluster ? 1 : 0
  display_name = local.kafka_cluster_display_name_res
  availability = var.kafka_availability
  cloud        = var.cloud_provider
  region       = var.cloud_region

  dynamic "basic" {
    for_each = var.kafka_cluster_tier == "basic" ? [1] : []
    content {}
  }

  dynamic "standard" {
    for_each = var.kafka_cluster_tier == "standard" ? [1] : []
    content {}
  }

  environment {
    id = local.env_id
  }
}

resource "confluent_flink_compute_pool" "pool" {
  count        = var.create_flink_compute_pool ? 1 : 0
  display_name = local.flink_compute_pool_display_name
  cloud        = upper(data.confluent_flink_region.flink_region.cloud)
  region       = data.confluent_flink_region.flink_region.region
  max_cfu      = var.flink_max_cfu

  environment {
    id = local.env_id
  }
}
