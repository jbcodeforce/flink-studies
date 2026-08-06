# -----------------------------------------------------------------------------
# Topics on primary + destination-initiated Cluster Link (primary → DR) + mirrors
# Gated by enable_cluster_link (iteration 2).
# DR must be Enterprise (see confluent.tf); primary stays Standard (source only).
# -----------------------------------------------------------------------------

locals {
  topic_names = toset([
    "rides_raw",
    "rides_clean",
    "driver_stats",
  ])
  cluster_link_topics = var.enable_cluster_link ? local.topic_names : toset([])
}

resource "confluent_kafka_topic" "primary" {
  for_each = local.cluster_link_topics

  kafka_cluster {
    id = data.confluent_kafka_cluster.primary.id
  }
  topic_name       = each.value
  partitions_count = var.topic_partitions
  rest_endpoint    = data.confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.app_manager_primary_kafka.id
    secret = confluent_api_key.app_manager_primary_kafka.secret
  }

  config = {
    "retention.ms" = "604800000" # 7 days — enough for stateful rebuild demos
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Destination-initiated link: DR (Enterprise) pulls from primary (source).
resource "confluent_cluster_link" "primary_to_dr" {
  count = var.enable_cluster_link ? 1 : 0

  link_name       = var.cluster_link_name
  link_mode       = "DESTINATION"
  connection_mode = "OUTBOUND"

  source_kafka_cluster {
    id                 = data.confluent_kafka_cluster.primary.id
    bootstrap_endpoint = data.confluent_kafka_cluster.primary.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.app_manager_primary_kafka.id
      secret = confluent_api_key.app_manager_primary_kafka.secret
    }
  }

  destination_kafka_cluster {
    id            = confluent_kafka_cluster.dr.id
    rest_endpoint = confluent_kafka_cluster.dr.rest_endpoint
    credentials {
      key    = confluent_api_key.app_manager_dr_kafka.id
      secret = confluent_api_key.app_manager_dr_kafka.secret
    }
  }

  depends_on = [
    confluent_role_binding.app_manager_env_admin_primary,
    confluent_role_binding.app_manager_env_admin_dr,
  ]
}

# Mirror topics on DR (destination must not already have these topics)
resource "confluent_kafka_mirror_topic" "dr" {
  for_each = local.cluster_link_topics

  source_kafka_topic {
    topic_name = each.value
  }

  cluster_link {
    link_name = confluent_cluster_link.primary_to_dr[0].link_name
  }

  kafka_cluster {
    id            = confluent_kafka_cluster.dr.id
    rest_endpoint = confluent_kafka_cluster.dr.rest_endpoint
    credentials {
      key    = confluent_api_key.app_manager_dr_kafka.id
      secret = confluent_api_key.app_manager_dr_kafka.secret
    }
  }

  depends_on = [
    confluent_kafka_topic.primary,
    confluent_cluster_link.primary_to_dr,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
