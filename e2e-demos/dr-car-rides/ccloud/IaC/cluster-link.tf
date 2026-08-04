# -----------------------------------------------------------------------------
# Topics on primary + bidirectional Cluster Link + mirror topics on DR
# -----------------------------------------------------------------------------

locals {
  topic_names = toset([
    "rides_raw",
    "rides_clean",
    "driver_stats",
  ])
}

resource "confluent_kafka_topic" "primary" {
  for_each = local.topic_names

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

# Bidirectional cluster link (both directions, same link_name)
resource "confluent_cluster_link" "primary_to_dr" {
  link_name = var.cluster_link_name
  link_mode = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = data.confluent_kafka_cluster.primary.id
    rest_endpoint = data.confluent_kafka_cluster.primary.rest_endpoint
    credentials {
      key    = confluent_api_key.app_manager_primary_kafka.id
      secret = confluent_api_key.app_manager_primary_kafka.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.dr.id
    bootstrap_endpoint = confluent_kafka_cluster.dr.bootstrap_endpoint
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

resource "confluent_cluster_link" "dr_to_primary" {
  link_name = var.cluster_link_name
  link_mode = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.dr.id
    rest_endpoint = confluent_kafka_cluster.dr.rest_endpoint
    credentials {
      key    = confluent_api_key.app_manager_dr_kafka.id
      secret = confluent_api_key.app_manager_dr_kafka.secret
    }
  }

  remote_kafka_cluster {
    id                 = data.confluent_kafka_cluster.primary.id
    bootstrap_endpoint = data.confluent_kafka_cluster.primary.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.app_manager_primary_kafka.id
      secret = confluent_api_key.app_manager_primary_kafka.secret
    }
  }

  depends_on = [
    confluent_cluster_link.primary_to_dr,
  ]
}

# Mirror topics on DR (destination must not already have these topics)
resource "confluent_kafka_mirror_topic" "dr" {
  for_each = local.topic_names

  source_kafka_topic {
    topic_name = each.value
  }

  cluster_link {
    link_name = confluent_cluster_link.dr_to_primary.link_name
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
    confluent_cluster_link.dr_to_primary,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
