# -----------------------------------------------------------------------------
# Producer — SA + role bindings + Kafka API key + SR API key + rides_raw topic
# The producer SA is separate from the Flink SA so keys can be rotated independently.
# rides_raw is the only source topic created here; rides_clean and driver_stats
# are created by Layer 2 (cluster-link) alongside their mirror topics.
# -----------------------------------------------------------------------------

resource "confluent_service_account" "dr_producer" {
  display_name = "${var.prefix}-dr-producer"
  description  = "Producer SA for DR car-rides demo (primary site)"

  lifecycle {
    prevent_destroy = false
  }
}

# --- Role bindings ---

resource "confluent_role_binding" "dr_producer_cluster_admin" {
  principal   = "User:${confluent_service_account.dr_producer.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.primary.rbac_crn

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_producer_sr_resource_owner" {
  principal   = "User:${confluent_service_account.dr_producer.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.primary.resource_name}/subject=*"

  lifecycle {
    prevent_destroy = false
  }
}

# --- API keys ---

resource "confluent_api_key" "producer_primary_kafka" {
  display_name = "${var.prefix}-dr-producer-primary-kafka"
  description  = "Kafka API key for DR demo producer on primary"

  owner {
    id          = confluent_service_account.dr_producer.id
    api_version = confluent_service_account.dr_producer.api_version
    kind        = confluent_service_account.dr_producer.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.primary.id
    api_version = data.confluent_kafka_cluster.primary.api_version
    kind        = data.confluent_kafka_cluster.primary.kind

    environment {
      id = data.confluent_environment.primary.id
    }
  }

  depends_on = [confluent_role_binding.dr_producer_cluster_admin]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "producer_sr_primary" {
  display_name = "${var.prefix}-dr-producer-sr-primary"
  description  = "Schema Registry API key for DR demo producer on primary"

  owner {
    id          = confluent_service_account.dr_producer.id
    api_version = confluent_service_account.dr_producer.api_version
    kind        = confluent_service_account.dr_producer.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.primary.id
    api_version = data.confluent_schema_registry_cluster.primary.api_version
    kind        = data.confluent_schema_registry_cluster.primary.kind

    environment {
      id = data.confluent_environment.primary.id
    }
  }

  depends_on = [confluent_role_binding.dr_producer_sr_resource_owner]

  lifecycle {
    prevent_destroy = false
  }
}

# --- Source topic ---
# rides_clean and driver_stats are created in Layer 2 alongside their mirrors.

resource "confluent_kafka_topic" "rides_raw" {
  kafka_cluster {
    id = data.confluent_kafka_cluster.primary.id
  }

  topic_name       = "rides_raw"
  partitions_count = var.topic_partitions
  rest_endpoint    = data.confluent_kafka_cluster.primary.rest_endpoint

  config = {
    "retention.ms" = "604800000" # 7 days — enough headroom for stateful rebuild demos
  }

  credentials {
    key    = confluent_api_key.producer_primary_kafka.id
    secret = confluent_api_key.producer_primary_kafka.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
