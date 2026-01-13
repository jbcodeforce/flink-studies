# -----------------------------------------------------------------------------
# Confluent Cloud Infrastructure
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------
resource "confluent_environment" "card_tx_env" {
  display_name = "${var.prefix}-environment-${random_id.env_display_id.hex}"

  stream_governance {
    package = "ADVANCED"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Schema Registry (auto-provisioned with ADVANCED governance)
# -----------------------------------------------------------------------------
data "confluent_schema_registry_cluster" "card_tx_sr" {
  environment {
    id = confluent_environment.card_tx_env.id
  }

  depends_on = [
    confluent_kafka_cluster.card_tx_cluster
  ]
}

# -----------------------------------------------------------------------------
# Kafka Cluster
# -----------------------------------------------------------------------------
resource "confluent_kafka_cluster" "card_tx_cluster" {
  display_name = "${var.prefix}-cluster-${random_id.env_display_id.hex}"
  availability = var.cc_availability
  cloud        = "AWS"
  region       = var.cloud_region

  standard {}

  environment {
    id = confluent_environment.card_tx_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Flink Compute Pool
# -----------------------------------------------------------------------------
resource "confluent_flink_compute_pool" "card_tx_flink_pool" {
  display_name = "${var.prefix}-compute-pool-${random_id.env_display_id.hex}"
  cloud        = "AWS"
  region       = var.cloud_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.card_tx_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Flink Region Data Source
# -----------------------------------------------------------------------------
data "confluent_flink_region" "card_tx_flink_region" {
  cloud  = "AWS"
  region = var.cloud_region
}

# -----------------------------------------------------------------------------
# Kafka Topics
# -----------------------------------------------------------------------------
# NOTE: Most topics are created automatically by Flink CREATE TABLE statements.
# However, we create topics here that are needed by connectors (like S3 sink)
# before Flink statements are deployed.

# Topic for enriched transactions (needed by S3 sink connector)
resource "confluent_kafka_topic" "card_tx_enriched" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  topic_name    = "${var.prefix}-enriched-transactions"
  partitions_count = 6

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin
  ]
}

# Topic for aggregations (needed by S3 sink connector)
resource "confluent_kafka_topic" "card_tx_aggregations" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  topic_name    = "${var.prefix}-tx-aggregations"
  partitions_count = 6

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin
  ]
}
