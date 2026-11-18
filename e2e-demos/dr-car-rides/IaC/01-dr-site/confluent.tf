# -----------------------------------------------------------------------------
# DR environment, Enterprise cluster, Schema Registry, Flink pool.
# A separate environment gives the DR site its own Schema Registry, which is
# required for Schema Linking (Layer 3).
# -----------------------------------------------------------------------------

resource "confluent_environment" "dr" {
  display_name = "${var.prefix}-dr"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Enterprise cluster: private networking only (PrivateLink Attachment, network.tf).
# HIGH availability: the DR destination of a Cluster Link.
resource "confluent_kafka_cluster" "dr" {
  display_name = "${var.prefix}-dr-kafka"
  availability = "HIGH"
  cloud        = "AWS"
  region       = var.dr_region

  enterprise {}

  environment {
    id = confluent_environment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Schema Registry is environment-scoped and auto-provisioned once a cluster exists.
data "confluent_schema_registry_cluster" "dr" {
  environment {
    id = confluent_environment.dr.id
  }

  depends_on = [confluent_kafka_cluster.dr]
}

resource "confluent_flink_compute_pool" "dr" {
  display_name = "${var.prefix}-flink-dr"
  cloud        = "AWS"
  region       = var.dr_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}
