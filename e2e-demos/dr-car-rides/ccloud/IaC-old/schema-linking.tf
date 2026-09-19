# -----------------------------------------------------------------------------
# Schema Linking — DR Schema Registry IMPORT + exporter primary → DR
# Gated by enable_schema_linking (iteration 2 with cluster link).
# -----------------------------------------------------------------------------

# Destination (DR) must be IMPORT so exported schemas keep the same IDs.
resource "confluent_schema_registry_cluster_mode" "dr_import" {
  count = var.enable_schema_linking ? 1 : 0

  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.dr.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.dr.rest_endpoint
  mode          = "IMPORT"
  # force allows switching to IMPORT even if default subjects exist
  force = true

  credentials {
    key    = confluent_api_key.app_manager_sr_dr.id
    secret = confluent_api_key.app_manager_sr_dr.secret
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin_dr,
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# Replicate all subjects from primary SR → DR SR (Schema Linking / exporter).
resource "confluent_schema_exporter" "primary_to_dr" {
  count = var.enable_schema_linking ? 1 : 0

  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.primary.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_sr_primary.id
    secret = confluent_api_key.app_manager_sr_primary.secret
  }

  name     = "${var.prefix}-schemas-to-dr"
  subjects = [":*:"]

  destination_schema_registry_cluster {
    rest_endpoint = data.confluent_schema_registry_cluster.dr.rest_endpoint
    credentials {
      key    = confluent_api_key.app_manager_sr_dr.id
      secret = confluent_api_key.app_manager_sr_dr.secret
    }
  }

  depends_on = [
    confluent_schema_registry_cluster_mode.dr_import,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
