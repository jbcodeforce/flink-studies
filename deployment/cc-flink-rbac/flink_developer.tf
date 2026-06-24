# FlinkDeveloper service account, role binding, and Flink-scoped API key.
# See docs/techno/ccloud-flink.md (RBAC section) and deployment/cc-terraform/flink.tf.

resource "confluent_service_account" "flink_developer" {
  display_name = "${var.prefix}-flink-dev-sa"
  description  = "FlinkDeveloper service account for RBAC study and statement deployment"
}

resource "confluent_role_binding" "flink_developer" {
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = "crn://confluent.cloud/organization=${local.org_id}/environment=${local.env_id}"
}

resource "confluent_api_key" "flink_developer" {
  display_name = "${var.prefix}-flink-dev-api-key"
  description  = "Flink API key owned by ${var.prefix}-flink-dev-sa (scoped to Flink region)"

  owner {
    id          = confluent_service_account.flink_developer.id
    api_version = confluent_service_account.flink_developer.api_version
    kind        = confluent_service_account.flink_developer.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind

    environment {
      id = local.env_id
    }
  }
}
