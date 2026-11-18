# Destination-initiated link: the DR (Enterprise, private) cluster pulls from the primary.
# The link lives on DR, so nothing has to reach into the primary network.
resource "confluent_cluster_link" "primary_to_dr" {
  link_name       = var.cluster_link_name
  link_mode       = "DESTINATION"
  connection_mode = "OUTBOUND"

  source_kafka_cluster {
    id                 = var.primary_kafka_cluster_id
    bootstrap_endpoint = var.primary_bootstrap_endpoint
    credentials {
      key    = var.primary_kafka_api_key
      secret = var.primary_kafka_api_secret
    }
  }

  destination_kafka_cluster {
    id            = var.dr_kafka_cluster_id
    rest_endpoint = var.dr_rest_endpoint
    credentials {
      key    = var.dr_kafka_api_key
      secret = var.dr_kafka_api_secret
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Mirror topics on DR. The source topics must already exist on primary, and the DR cluster
# must not hold topics with these names.
resource "confluent_kafka_mirror_topic" "dr" {
  for_each = toset(var.mirror_topics)

  source_kafka_topic {
    topic_name = each.value
  }

  cluster_link {
    link_name = confluent_cluster_link.primary_to_dr.link_name
  }

  kafka_cluster {
    id            = var.dr_kafka_cluster_id
    rest_endpoint = var.dr_rest_endpoint
    credentials {
      key    = var.dr_kafka_api_key
      secret = var.dr_kafka_api_secret
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
