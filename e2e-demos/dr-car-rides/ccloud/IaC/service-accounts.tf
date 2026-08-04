# -----------------------------------------------------------------------------
# Service accounts (reused from j9r), role bindings, API keys
# -----------------------------------------------------------------------------

data "confluent_service_account" "app_manager" {
  id = data.terraform_remote_state.j9r.outputs.env_manager_sa_id
}

data "confluent_service_account" "flink" {
  id = data.terraform_remote_state.j9r.outputs.flink_app_sa_id
}

data "confluent_service_account" "producer" {
  id = data.terraform_remote_state.j9r.outputs.kafka_mgr_sa_id
}

# --- Environment admin / Flink developer on both envs ---
resource "confluent_role_binding" "app_manager_env_admin_primary" {
  principal   = "User:${data.confluent_service_account.app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = data.confluent_environment.primary.resource_name
}

resource "confluent_role_binding" "app_manager_env_admin_dr" {
  principal   = "User:${data.confluent_service_account.app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.dr.resource_name
}

resource "confluent_role_binding" "flink_developer_primary" {
  principal   = "User:${data.confluent_service_account.flink.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = data.confluent_environment.primary.resource_name
}

resource "confluent_role_binding" "flink_developer_dr" {
  principal   = "User:${data.confluent_service_account.flink.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.dr.resource_name
}

resource "confluent_role_binding" "flink_primary_cluster_admin" {
  principal   = "User:${data.confluent_service_account.flink.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.primary.rbac_crn
}

resource "confluent_role_binding" "flink_dr_cluster_admin" {
  principal   = "User:${data.confluent_service_account.flink.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dr.rbac_crn
}

resource "confluent_role_binding" "producer_primary_cluster_admin" {
  principal   = "User:${data.confluent_service_account.producer.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.primary.rbac_crn
}

resource "confluent_role_binding" "producer_dr_cluster_admin" {
  principal   = "User:${data.confluent_service_account.producer.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dr.rbac_crn
}

resource "confluent_role_binding" "producer_sr_primary" {
  principal   = "User:${data.confluent_service_account.producer.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.primary.resource_name}/subject=*"
}

resource "confluent_role_binding" "producer_sr_dr" {
  principal   = "User:${data.confluent_service_account.producer.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.dr.resource_name}/subject=*"
}

# --- Kafka API keys ---
resource "confluent_api_key" "app_manager_primary_kafka" {
  display_name = "${var.prefix}-app-mgr-primary-kafka"
  owner {
    id          = data.confluent_service_account.app_manager.id
    api_version = data.confluent_service_account.app_manager.api_version
    kind        = data.confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = data.confluent_kafka_cluster.primary.id
    api_version = data.confluent_kafka_cluster.primary.api_version
    kind        = data.confluent_kafka_cluster.primary.kind
    environment {
      id = data.confluent_environment.primary.id
    }
  }
  depends_on = [confluent_role_binding.app_manager_env_admin_primary]
}

resource "confluent_api_key" "app_manager_dr_kafka" {
  display_name = "${var.prefix}-app-mgr-dr-kafka"
  owner {
    id          = data.confluent_service_account.app_manager.id
    api_version = data.confluent_service_account.app_manager.api_version
    kind        = data.confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.dr.id
    api_version = confluent_kafka_cluster.dr.api_version
    kind        = confluent_kafka_cluster.dr.kind
    environment {
      id = confluent_environment.dr.id
    }
  }
  depends_on = [confluent_role_binding.app_manager_env_admin_dr]
}

# --- Schema Registry API keys (both sides — required for Schema Linking) ---
resource "confluent_api_key" "app_manager_sr_primary" {
  display_name = "${var.prefix}-app-mgr-sr-primary"
  owner {
    id          = data.confluent_service_account.app_manager.id
    api_version = data.confluent_service_account.app_manager.api_version
    kind        = data.confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.primary.id
    api_version = data.confluent_schema_registry_cluster.primary.api_version
    kind        = data.confluent_schema_registry_cluster.primary.kind
    environment {
      id = data.confluent_environment.primary.id
    }
  }
  depends_on = [confluent_role_binding.app_manager_env_admin_primary]
}

resource "confluent_api_key" "app_manager_sr_dr" {
  display_name = "${var.prefix}-app-mgr-sr-dr"
  owner {
    id          = data.confluent_service_account.app_manager.id
    api_version = data.confluent_service_account.app_manager.api_version
    kind        = data.confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.dr.id
    api_version = data.confluent_schema_registry_cluster.dr.api_version
    kind        = data.confluent_schema_registry_cluster.dr.kind
    environment {
      id = confluent_environment.dr.id
    }
  }
  depends_on = [confluent_role_binding.app_manager_env_admin_dr]
}

resource "confluent_api_key" "flink_primary" {
  display_name = "${var.prefix}-flink-primary"
  owner {
    id          = data.confluent_service_account.flink.id
    api_version = data.confluent_service_account.flink.api_version
    kind        = data.confluent_service_account.flink.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.primary.id
    api_version = data.confluent_flink_region.primary.api_version
    kind        = data.confluent_flink_region.primary.kind
    environment {
      id = data.confluent_environment.primary.id
    }
  }
  depends_on = [
    confluent_role_binding.flink_developer_primary,
    confluent_role_binding.flink_primary_cluster_admin,
  ]
}

resource "confluent_api_key" "flink_dr" {
  display_name = "${var.prefix}-flink-dr"
  owner {
    id          = data.confluent_service_account.flink.id
    api_version = data.confluent_service_account.flink.api_version
    kind        = data.confluent_service_account.flink.kind
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
    confluent_role_binding.flink_developer_dr,
    confluent_role_binding.flink_dr_cluster_admin,
  ]
}

resource "confluent_api_key" "producer_primary_kafka" {
  display_name = "${var.prefix}-producer-primary-kafka"
  owner {
    id          = data.confluent_service_account.producer.id
    api_version = data.confluent_service_account.producer.api_version
    kind        = data.confluent_service_account.producer.kind
  }
  managed_resource {
    id          = data.confluent_kafka_cluster.primary.id
    api_version = data.confluent_kafka_cluster.primary.api_version
    kind        = data.confluent_kafka_cluster.primary.kind
    environment {
      id = data.confluent_environment.primary.id
    }
  }
  depends_on = [confluent_role_binding.producer_primary_cluster_admin]
}

resource "confluent_api_key" "producer_dr_kafka" {
  display_name = "${var.prefix}-producer-dr-kafka"
  owner {
    id          = data.confluent_service_account.producer.id
    api_version = data.confluent_service_account.producer.api_version
    kind        = data.confluent_service_account.producer.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.dr.id
    api_version = confluent_kafka_cluster.dr.api_version
    kind        = confluent_kafka_cluster.dr.kind
    environment {
      id = confluent_environment.dr.id
    }
  }
  depends_on = [confluent_role_binding.producer_dr_cluster_admin]
}

resource "confluent_api_key" "producer_sr_primary" {
  display_name = "${var.prefix}-producer-sr-primary"
  owner {
    id          = data.confluent_service_account.producer.id
    api_version = data.confluent_service_account.producer.api_version
    kind        = data.confluent_service_account.producer.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.primary.id
    api_version = data.confluent_schema_registry_cluster.primary.api_version
    kind        = data.confluent_schema_registry_cluster.primary.kind
    environment {
      id = data.confluent_environment.primary.id
    }
  }
  depends_on = [confluent_role_binding.producer_sr_primary]
}

resource "confluent_api_key" "producer_sr_dr" {
  display_name = "${var.prefix}-producer-sr-dr"
  owner {
    id          = data.confluent_service_account.producer.id
    api_version = data.confluent_service_account.producer.api_version
    kind        = data.confluent_service_account.producer.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.dr.id
    api_version = data.confluent_schema_registry_cluster.dr.api_version
    kind        = data.confluent_schema_registry_cluster.dr.kind
    environment {
      id = confluent_environment.dr.id
    }
  }
  depends_on = [confluent_role_binding.producer_sr_dr]
}

resource "confluent_api_key" "tableflow" {
  count        = var.enable_tableflow ? 1 : 0
  display_name = "${var.prefix}-tableflow"
  owner {
    id          = data.confluent_service_account.app_manager.id
    api_version = data.confluent_service_account.app_manager.api_version
    kind        = data.confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"
  }
  depends_on = [
    confluent_role_binding.app_manager_env_admin_primary,
    confluent_role_binding.app_manager_env_admin_dr,
  ]
}
