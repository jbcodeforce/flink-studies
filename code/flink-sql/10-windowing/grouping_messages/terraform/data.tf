data "confluent_organization" "org" {}

data "confluent_environment" "env" {
  id = var.environment_id
}

data "confluent_kafka_cluster" "cluster" {
  id = var.kafka_cluster_id
  environment {
    id = var.environment_id
  }
}

locals {
  flink_properties = {
    "sql.current-catalog"  = data.confluent_environment.env.display_name
    "sql.current-database" = data.confluent_kafka_cluster.cluster.display_name
  }
}
