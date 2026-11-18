# -----------------------------------------------------------------------------
# Flink — DR-demo compute pool + SA + role bindings + API key
# Scoped to the existing primary environment.
# -----------------------------------------------------------------------------

# Dedicated service account for the DR demo Flink workload.
# Keeping this separate from the base flink-developer-sa in cc-terraform
# means this layer can be destroyed independently.
resource "confluent_service_account" "dr_flink" {
  display_name = "${var.prefix}-dr-flink"
  description  = "Flink SA for DR car-rides demo (primary site)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_flink_developer" {
  principal   = "User:${confluent_service_account.dr_flink.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = data.confluent_environment.primary.resource_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "dr_flink_cluster_admin" {
  principal   = "User:${confluent_service_account.dr_flink.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.primary.rbac_crn

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_flink_compute_pool" "primary" {
  display_name = "${var.prefix}-dr-flink-primary"
  cloud        = "AWS"
  region       = var.primary_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = data.confluent_environment.primary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "flink_primary" {
  display_name = "${var.prefix}-dr-flink-primary-key"
  description  = "Flink API key for DR demo on primary site"

  owner {
    id          = confluent_service_account.dr_flink.id
    api_version = confluent_service_account.dr_flink.api_version
    kind        = confluent_service_account.dr_flink.kind
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
    confluent_role_binding.dr_flink_developer,
    confluent_role_binding.dr_flink_cluster_admin,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
