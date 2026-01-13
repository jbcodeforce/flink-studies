# -----------------------------------------------------------------------------
# Service Accounts, API Keys, and ACLs
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

# App Manager - Full environment admin for cluster management
resource "confluent_service_account" "app_manager" {
  display_name = "${var.prefix}-app-manager-${random_id.env_display_id.hex}"
  description  = "Service account for managing Card TX demo resources"

  lifecycle {
    prevent_destroy = false
  }
}

# Connectors - For CDC and Sink connectors
resource "confluent_service_account" "connectors" {
  display_name = "${var.prefix}-connectors-${random_id.env_display_id.hex}"
  description  = "Service account for Card TX connectors"

  lifecycle {
    prevent_destroy = false
  }
}

# Flink - For Flink SQL statements
resource "confluent_service_account" "flink" {
  display_name = "${var.prefix}-flink-${random_id.env_display_id.hex}"
  description  = "Service account for Card TX Flink processing"

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Role Bindings
# -----------------------------------------------------------------------------

# App Manager - Environment Admin
resource "confluent_role_binding" "app_manager_env_admin" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.card_tx_env.resource_name

  lifecycle {
    prevent_destroy = false
  }
}

# Flink - FlinkDeveloper role
resource "confluent_role_binding" "flink_developer" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.card_tx_env.resource_name

  lifecycle {
    prevent_destroy = false
  }
}

# Flink - Cluster Admin for topic access
resource "confluent_role_binding" "flink_cluster_admin" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.card_tx_cluster.rbac_crn

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# API Keys
# -----------------------------------------------------------------------------

# App Manager - Kafka API Key
resource "confluent_api_key" "app_manager_kafka_key" {
  display_name = "${var.prefix}-app-manager-kafka-key"
  description  = "Kafka API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.card_tx_cluster.id
    api_version = confluent_kafka_cluster.card_tx_cluster.api_version
    kind        = confluent_kafka_cluster.card_tx_cluster.kind

    environment {
      id = confluent_environment.card_tx_env.id
    }
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# App Manager - Schema Registry API Key
resource "confluent_api_key" "app_manager_sr_key" {
  display_name = "${var.prefix}-app-manager-sr-key"
  description  = "Schema Registry API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.card_tx_sr.id
    api_version = data.confluent_schema_registry_cluster.card_tx_sr.api_version
    kind        = data.confluent_schema_registry_cluster.card_tx_sr.kind

    environment {
      id = confluent_environment.card_tx_env.id
    }
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# App Manager - Flink API Key
resource "confluent_api_key" "app_manager_flink_key" {
  display_name = "${var.prefix}-app-manager-flink-key"
  description  = "Flink API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.card_tx_flink_region.id
    api_version = data.confluent_flink_region.card_tx_flink_region.api_version
    kind        = data.confluent_flink_region.card_tx_flink_region.kind

    environment {
      id = confluent_environment.card_tx_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# App Manager - Tableflow API Key
resource "confluent_api_key" "app_manager_tableflow_key" {
  count = var.enable_tableflow ? 1 : 0

  display_name = "${var.prefix}-app-manager-tableflow-key"
  description  = "Tableflow API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# ACLs for Connectors Service Account
# -----------------------------------------------------------------------------

resource "confluent_kafka_acl" "connectors_create_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.connectors.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "connectors_write_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.connectors.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "connectors_read_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.connectors.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "connectors_describe_cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.connectors.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "connectors_read_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.connectors.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.card_tx_cluster.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_kafka_key.id
    secret = confluent_api_key.app_manager_kafka_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
