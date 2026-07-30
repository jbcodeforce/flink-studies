# -----------------------------------------------------------------------------
# Confluent Cloud — two environments (primary + DR), clusters, Flink pools
# Two envs are required so each side has its own Schema Registry for Schema Linking.
# -----------------------------------------------------------------------------

resource "confluent_environment" "primary" {
  display_name = "${var.prefix}-primary-${random_id.suffix.hex}"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_environment" "dr" {
  display_name = "${var.prefix}-dr-${random_id.suffix.hex}"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_cluster" "primary" {
  display_name = "${var.prefix}-primary-kafka-${random_id.suffix.hex}"
  availability = var.cc_availability
  cloud        = "AWS"
  region       = var.primary_region

  standard {}

  environment {
    id = confluent_environment.primary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_cluster" "dr" {
  display_name = "${var.prefix}-dr-kafka-${random_id.suffix.hex}"
  availability = var.cc_availability
  cloud        = "AWS"
  region       = var.dr_region

  standard {}

  environment {
    id = confluent_environment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Schema Registry is environment-scoped — one per env after Kafka exists.
data "confluent_schema_registry_cluster" "primary" {
  environment {
    id = confluent_environment.primary.id
  }

  depends_on = [confluent_kafka_cluster.primary]
}

data "confluent_schema_registry_cluster" "dr" {
  environment {
    id = confluent_environment.dr.id
  }

  depends_on = [confluent_kafka_cluster.dr]
}

resource "confluent_flink_compute_pool" "primary" {
  display_name = "${var.prefix}-flink-primary-${random_id.suffix.hex}"
  cloud        = "AWS"
  region       = var.primary_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.primary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_flink_compute_pool" "dr" {
  display_name = "${var.prefix}-flink-dr-${random_id.suffix.hex}"
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

data "confluent_flink_region" "primary" {
  cloud  = "AWS"
  region = var.primary_region
}

data "confluent_flink_region" "dr" {
  cloud  = "AWS"
  region = var.dr_region
}

# Tableflow provider integration is per-environment (shared IAM role, regional buckets).
resource "confluent_provider_integration" "tableflow_primary" {
  count = var.enable_tableflow ? 1 : 0

  environment {
    id = confluent_environment.primary.id
  }

  display_name = "${var.prefix}-tableflow-pi-primary-${random_id.suffix.hex}"

  aws {
    customer_role_arn = local.tableflow_role_arn
  }

  depends_on = [
    aws_iam_role.tableflow,
    aws_iam_role_policy.tableflow_combined,
  ]
}

resource "confluent_provider_integration" "tableflow_dr" {
  count = var.enable_tableflow ? 1 : 0

  environment {
    id = confluent_environment.dr.id
  }

  display_name = "${var.prefix}-tableflow-pi-dr-${random_id.suffix.hex}"

  aws {
    customer_role_arn = local.tableflow_role_arn
  }

  depends_on = [
    aws_iam_role.tableflow,
    aws_iam_role_policy.tableflow_combined,
  ]
}
