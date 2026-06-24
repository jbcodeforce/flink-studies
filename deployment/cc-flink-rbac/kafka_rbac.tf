# Kafka RBAC for FlinkDeveloper on Standard clusters (resource-scoped roles).
# Basic clusters do not support topic/transactional-id role bindings.
# See https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html

locals {
  kafka_rbac_enabled = var.create_kafka_cluster && var.kafka_cluster_tier == "standard"

  kafka_rbac_base = local.kafka_rbac_enabled ? (
    "${confluent_kafka_cluster.kafka[0].rbac_crn}/kafka=${confluent_kafka_cluster.kafka[0].id}"
  ) : ""
}

resource "confluent_role_binding" "flink_developer_topic_read" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_rbac_base}/topic=${var.kafka_topic_pattern}"
}

resource "confluent_role_binding" "flink_developer_topic_write" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_rbac_base}/topic=${var.kafka_topic_pattern}"
}

# CREATE TABLE / CTAS: create Kafka topics backing Flink tables.
resource "confluent_role_binding" "flink_developer_topic_manage" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${local.kafka_rbac_base}/topic=${var.kafka_topic_pattern}"
}

resource "confluent_role_binding" "flink_developer_txn_read" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_rbac_base}/transactional-id=${var.flink_transactional_id_prefix}*"
}

resource "confluent_role_binding" "flink_developer_txn_write" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_rbac_base}/transactional-id=${var.flink_transactional_id_prefix}*"
}
