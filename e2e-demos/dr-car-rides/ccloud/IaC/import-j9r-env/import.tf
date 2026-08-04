# Import only the j9r primary environment, its Kafka cluster, and one SA.
# Kafka cluster import ID format: <environment_id>/<cluster_id>

import {
  to = confluent_environment.env
  id = var.environment_id
}

import {
  to = confluent_kafka_cluster.standard
  id = "${var.environment_id}/${var.kafka_cluster_id}"
}

import {
  to = confluent_service_account.env-manager
  id = var.env_manager_sa_id
}
