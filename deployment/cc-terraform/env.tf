# CC Environment and service account to manage the environment

resource "confluent_environment" "env" {
  display_name = var.lab_name

  stream_governance {
    package = "ADVANCED"
  }
}

resource "confluent_service_account" "env-manager" {
  display_name = "${var.lab_name}-env-manager"
  description  = "Service account to manage ${var.lab_name} environment"
  depends_on = [
    confluent_environment.env
  ]
}

resource "confluent_role_binding" "env-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.env.resource_name
 }



resource "confluent_api_key" "schema-registry-api-key" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.essentials.id
    api_version = data.confluent_schema_registry_cluster.essentials.api_version
    kind        = data.confluent_schema_registry_cluster.essentials.kind

    environment {
      id = confluent_environment.env.id
    }
  }

  depends_on = [
      confluent_service_account.env-manager
  ]
}