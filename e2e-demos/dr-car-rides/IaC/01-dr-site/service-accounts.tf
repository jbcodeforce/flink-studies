# -----------------------------------------------------------------------------
# DR service account, role bindings and API keys.
# One SA owns every DR key (Flink, Kafka, Schema Registry); Layers 2 and 3 use it
# for the cluster link destination and the schema exporter target.
# -----------------------------------------------------------------------------

resource "confluent_service_account" "dr_manager" {
  display_name = "${var.prefix}-dr-manager"
  description  = "Manager SA for the DR car-rides demo (DR site)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_env_admin" {
  principal   = "User:${confluent_service_account.dr_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.dr.resource_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_flink_developer" {
  principal   = "User:${confluent_service_account.dr_manager.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.dr.resource_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_cluster_admin" {
  principal   = "User:${confluent_service_account.dr_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dr.rbac_crn

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_sr_resource_owner" {
  principal   = "User:${confluent_service_account.dr_manager.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.dr.resource_name}/subject=*"

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "flink_dr" {
  display_name = "${var.prefix}-dr-flink-dr-key"
  description  = "Flink API key for the DR site"

  owner {
    id          = confluent_service_account.dr_manager.id
    api_version = confluent_service_account.dr_manager.api_version
    kind        = confluent_service_account.dr_manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.dr.id
    api_version = data.confluent_flink_region.dr.api_version
    kind        = data.confluent_flink_region.dr.kind

    environment {
      id = confluent_environment.dr.id
    }
  }

  depends_on = [
    confluent_role_binding.dr_flink_developer,
    confluent_role_binding.dr_cluster_admin,
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "producer_dr_kafka" {
  display_name = "${var.prefix}-dr-producer-dr-kafka"
  description  = "Kafka API key for the DR cluster (producer, cluster link, loss sampling)"

  # The DR cluster is private: its REST endpoint does not resolve from the laptop, so the
  # provider cannot confirm the key is ready by listing topics. Skip that check.
  disable_wait_for_ready = true

  owner {
    id          = confluent_service_account.dr_manager.id
    api_version = confluent_service_account.dr_manager.api_version
    kind        = confluent_service_account.dr_manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dr.id
    api_version = confluent_kafka_cluster.dr.api_version
    kind        = confluent_kafka_cluster.dr.kind

    environment {
      id = confluent_environment.dr.id
    }
  }

  depends_on = [confluent_role_binding.dr_cluster_admin]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "producer_sr_dr" {
  display_name = "${var.prefix}-dr-producer-sr-dr"
  description  = "Schema Registry API key for the DR site (producer, schema exporter target)"

  owner {
    id          = confluent_service_account.dr_manager.id
    api_version = confluent_service_account.dr_manager.api_version
    kind        = confluent_service_account.dr_manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.dr.id
    api_version = data.confluent_schema_registry_cluster.dr.api_version
    kind        = data.confluent_schema_registry_cluster.dr.kind

    environment {
      id = confluent_environment.dr.id
    }
  }

  depends_on = [confluent_role_binding.dr_sr_resource_owner]

  lifecycle {
    prevent_destroy = false
  }
}
