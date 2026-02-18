# Flink Service Accounts, Role Bindings, and API Keys
# for j9r-env base infrastructure

# ------------------------------------------------------
# Flink Developer (deploys Flink statements)
# ------------------------------------------------------

resource "confluent_service_account" "flink-developer-sa" {
  display_name = "${var.prefix}-fd-sa"
  description  = "Service account to deploy Flink statements in the environment"
}

resource "confluent_role_binding" "flink-developer-sa-flink-developer" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.env.resource_name
}

resource "confluent_api_key" "flink-developer-sa-flink-api-key" {
  display_name = "flink-developer-sa-flink-api-key"
  description  = "Flink API Key that is owned by 'flink-developer-sa' service account"
  owner {
    id          = confluent_service_account.flink-developer-sa.id
    api_version = confluent_service_account.flink-developer-sa.api_version
    kind        = confluent_service_account.flink-developer-sa.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind

    environment {
      id = confluent_environment.env.id
    }
  }
}
