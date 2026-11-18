# Destination (DR) must be IMPORT so exported schemas keep their ids.
resource "confluent_schema_registry_cluster_mode" "dr_import" {
  schema_registry_cluster {
    id = var.dr_schema_registry_id
  }
  rest_endpoint = var.dr_schema_registry_rest_endpoint
  mode          = "IMPORT"
  # force allows switching to IMPORT even if subjects already exist
  force = true

  credentials {
    key    = var.dr_sr_api_key
    secret = var.dr_sr_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Replicate ONLY this demo's subjects. The primary registry is shared with other projects
# (hundreds of subjects), so a ":*:" exporter would copy all of them into DR.
resource "confluent_schema_exporter" "primary_to_dr" {
  schema_registry_cluster {
    id = var.primary_schema_registry_id
  }
  rest_endpoint = var.primary_schema_registry_rest_endpoint

  credentials {
    key    = var.primary_sr_api_key
    secret = var.primary_sr_api_secret
  }

  name     = var.schema_exporter_name
  subjects = var.exported_subjects

  # NONE keeps subjects in the DR default context under their original names. With the
  # default (AUTO) they land in a ".<source-registry-id>" context, which the DR producer and
  # Flink tables never look in, and schema ids stop lining up.
  context_type = "NONE"

  destination_schema_registry_cluster {
    rest_endpoint = var.dr_schema_registry_rest_endpoint
    credentials {
      key    = var.dr_sr_api_key
      secret = var.dr_sr_api_secret
    }
  }

  depends_on = [confluent_schema_registry_cluster_mode.dr_import]

  lifecycle {
    prevent_destroy = false
  }
}
