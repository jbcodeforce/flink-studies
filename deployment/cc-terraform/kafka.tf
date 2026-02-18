# Kafka Cluster and Service Accounts for j9r-env base infrastructure

resource "confluent_kafka_cluster" "standard" {
  display_name = "${var.prefix}-kafka"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  standard {}

  environment {
    id = confluent_environment.env.id
  }

  depends_on = [
    confluent_environment.env
  ]
}

resource "confluent_api_key" "standard-kafka-api-key" {
  display_name = "standard-kafka-api-key"
  description  = "Kafka API Key for 'standard' cluster"
  owner {
    id          = data.confluent_service_account.env-manager.id
    api_version = data.confluent_service_account.env-manager.api_version
    kind        = data.confluent_service_account.env-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind

    environment {
      id = confluent_environment.env.id
    }
  }

  depends_on = [
    confluent_kafka_cluster.standard,
    data.confluent_service_account.env-manager
  ]
}

# ------------------------------------------------------
# Service account for Kafka cluster administration
# ------------------------------------------------------

resource "confluent_service_account" "kafka-mgr" {
  display_name = "${var.prefix}-kafka-mgr"
  description  = "Service account to manage 'standard' Kafka cluster"
}

resource "confluent_role_binding" "kafka-mgr-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.kafka-mgr.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}


