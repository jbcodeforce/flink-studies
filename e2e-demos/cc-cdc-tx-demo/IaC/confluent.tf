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
# Provider Integration for Tableflow BYOB AWS
# -----------------------------------------------------------------------------
# Create provider integration if tableflow_provider_integration_id is not provided
resource "confluent_provider_integration" "tableflow_aws" {
  count = var.enable_tableflow && var.tableflow_provider_integration_id == "" ? 1 : 0

  environment {
    id = confluent_environment.card_tx_env.id
  }

  display_name = "${var.prefix}-tableflow-provider-integration-${random_id.env_display_id.hex}"

  aws {
    customer_role_arn = local.tableflow_role_arn
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Use created provider integration or provided one
locals {
  tableflow_provider_integration_id = var.tableflow_provider_integration_id != "" ? var.tableflow_provider_integration_id : (var.enable_tableflow ? confluent_provider_integration.tableflow_aws[0].id : "")
}
